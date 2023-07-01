using LibPeer.Networks;
using LibPeer.Protocols.Mx2;
using LibPeer.Util;

using Gee;

namespace LibPeer.Networks.IPv4 {

    public class IPv4 : Network {

        private IPv4PeerInfo local_peer;
        private InetSocketAddress socket_address;
        private Socket socket;
        private Socket multicast_socket;
        private InetSocketAddress multicast_address;
        private HashSet<InstanceReference> advertised_instances = new HashSet<InstanceReference>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        public bool local_only { get; private set; }

        private static uint8[] multicast_magic_number = new uint8[] {'L', 'i', 'b', 'P', 'e', 'e', 'r', '2', '-', 'I', 'P', 'v', '4', ':'};
        private const uint8 DGRAM_DATA = 0;
        private const uint8 DGRAM_INQUIRE = 1;
        private const uint8 DGRAM_INSTANCE = 2;

        private static string[] dns_seeds = new string[] {
            "libpeer.localresolver",
            "libpeer.pcthingz.com",
            "libpeer.unitatem.net",
            "libpeer.mooo.com",
            "libpeer.barrow.nz"
        };

        public IPv4(string address, uint16 port, bool local_only = false) {
            this.local_only = local_only;
            socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            multicast_socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            var inet_address = new InetAddress.from_string(address);
            socket_address = new InetSocketAddress(inet_address, port);
            local_peer = new IPv4PeerInfo(socket_address);
            multicast_address = new InetSocketAddress(new InetAddress.from_string("224.0.0.3"), 1199);
        }

        public static IPv4 automatic(bool local_only = false) {
            return new IPv4("0.0.0.0", IPv4.find_free_port("0.0.0.0"), local_only);
        }

        public override Bytes get_network_identifier() {
            return new Bytes({'I', 'P', 'v', '4'});
        }

        public override uint16 get_mtu() {
            return 511;
        }

        public override void bring_up() throws IOError, Error {
            // Bind the main socket
            socket.bind(socket_address, false);

            // Setup multicast socket
            multicast_socket.bind(multicast_address, true);
            multicast_socket.join_multicast_group(multicast_address.get_address(), false, null);

            new Thread<bool>("LibPeer IPv4 Listener", listen);
            new Thread<bool>("LibPeer IPv4 Local Discovery", multicast_listen);
            new Thread<bool>("LibPeer IPv4 DNS Discovery", dns_discovery);
        }

        public override void bring_down() throws IOError, Error {
            warning("[IPv4] Bring down not yet implemented...\n");
        }

        public override void advertise(InstanceReference instance_reference) throws IOError, Error {
            var stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            var dos = StreamUtil.get_data_output_stream(stream);

            dos.write(multicast_magic_number);
            dos.put_uint16(socket_address.get_port());
            instance_reference.serialise(dos);

            stream.flush();
            stream.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();

            multicast_socket.send_to(multicast_address, buffer);
            advertised_instances.add(instance_reference);
        }

        private bool address_allowed(InetAddress address) {
            return !local_only || address.is_site_local || address.is_link_local;
        }

        public override void send(uint8[] bytes, PeerInfo peer_info) throws IOError, Error {
            var ipv4_info = (IPv4PeerInfo)peer_info;

            var address = ipv4_info.to_socket_address();
            if(!address_allowed(address.address)) {
                throw new IOError.NETWORK_UNREACHABLE("IPv4 address of remote peer is not site-local or link-local and network has been set to local-only mode.");
            }

            var buffer = new ByteComposer().add_byte(DGRAM_DATA).add_byte_array(bytes).to_byte_array();
            socket.send_to(address, buffer);
        }

        public override bool peer_globally_routable(PeerInfo peer_info) {
            if(local_only) {
                return false;
            }

            var ipv4_info = (IPv4PeerInfo)peer_info;
            InetAddress address = ipv4_info.to_socket_address().address;
            return !(address.is_link_local || address.is_loopback || address.is_multicast || address.is_site_local);
        }

        private bool listen() {
            while(true) {
                try {
                    // Receive the next datagram
                    var buffer = new uint8[65536];
                    SocketAddress address;
                    var size = socket.receive_from(out address, buffer);
                    var ip_address = (InetSocketAddress)address;
                    buffer.length = (int)size;

                    if(!address_allowed(ip_address.address)) {
                        continue;
                    }

                    // Put the datagram into a stream
                    var stream = new MemoryInputStream.from_data(buffer);

                    // Create peer info
                    var info = new IPv4PeerInfo(ip_address);

                    // Read the datagram type
                    var type = new uint8[1];
                    stream.read(type);

                    switch (type[0]) {
                        case DGRAM_DATA:
                            // Create a new receiption
                            var receiption = new Receiption(stream, info, this);

                            // Pass up
                            incoming_receiption(receiption);
                            break;
                        
                        case DGRAM_INQUIRE:
                            // Respond with instance information
                            foreach (var instance in advertised_instances) {
                                // Send the instance information as a single datagram
                                var payload = new ByteComposer().add_byte(DGRAM_INSTANCE).add_bytes(instance.to_bytes()).to_byte_array();
                                socket.send_to(address, payload);
                            }
                            break;

                        case DGRAM_INSTANCE:
                            // Create the instance reference
                            var instance_reference = new InstanceReference.from_stream(stream);

                            // Is the instance one we advertise?
                            if(advertised_instances.contains(instance_reference)) {
                                // Yes, skip
                                continue;
                            }

                            // Create the advertisement
                            var advertisement = new Advertisement(instance_reference, info);

                            // Send to the application
                            incoming_advertisment(advertisement);
                            break;
                    }
                }
                catch(Error e) {
                    error(@"Exception on incoming packet: $(e.message)");
                }
            }
            return false;
        }

        private bool multicast_listen() {
            while(true) {
                // Receive the next discovery datagram
                var buffer = new uint8[InstanceReference.SERIALISED_SIZE + 16];
                SocketAddress address;
                multicast_socket.receive_from(out address, buffer);
                var inet_address = (InetSocketAddress)address;

                var stream = new MemoryInputStream.from_data(buffer);
                var dis = StreamUtil.get_data_input_stream(stream);

                var magic_number = dis.read_bytes(multicast_magic_number.length);
                if(magic_number.compare(new Bytes(multicast_magic_number)) != 0) {
                    // Invalid magic number
                    continue;
                }

                // Get advertised port number
                var port = dis.read_uint16();

                // Create peer info
                var info = new IPv4PeerInfo(new InetSocketAddress(inet_address.get_address(), port));

                // Create the instance reference
                var instance_reference = new InstanceReference.from_stream(dis);

                // Is the instance one we advertise?
                if(advertised_instances.contains(instance_reference)) {
                    // Yes, skip
                    continue;
                }

                // Create the advertisement
                var advertisement = new Advertisement(instance_reference, info);

                // Send to the application
                incoming_advertisment(advertisement);
                
            }
            return false;
        }

        private bool dns_discovery() {
            // Loop over each DNS seed
            var resolver = Resolver.get_default();
            foreach (var domain in dns_seeds) {
                // Try and query
                try {
                    var results = resolver.lookup_records(domain, ResolverRecordType.TXT);
                    foreach (var result in results) {

                        foreach (var child in result) {
                            foreach (var line in child.get_strv()) {
                                // Is this a LibPeer entry?
                                if(line.substring(0, 2) != "P2") {
                                    continue;
                                }

                                // Split on delimiter
                                var data = line.split("/");

                                if(data[0] == "P2M") {
                                    // Seed message
                                    stderr.printf(@"[LibPeer] DNS Seed MotD ($(domain)): $(data[1])\n");
                                }
                                else if(data[0] == "P2D") {
                                    try {
                                        //  print(@"Lookup address to inquire: $(data[1])\n");
                                        var addresses = resolver.lookup_by_name(data[1]);
                                        foreach (var address in addresses) {
                                            inquire(address, int.parse(data[2]));
                                        }
                                    }
                                    catch {}
                                }
                                else if(data[0] == "P2A") {
                                    inquire(new InetAddress.from_string(data[1]), int.parse(data[2]));
                                }
                            }
                        }
                    }
                }
                catch {}
            }
            return true;
        }

        private void inquire(InetAddress address, int port) {
            if(!address_allowed(address)) {
                printerr(@"Not sending IPv4 inquiry for instances to $(address.to_string()):$(port) as network has been set to local-only mode\n");
                return;
            }
            printerr(@"Sending IPv4 inquiry for instances to $(address.to_string()):$(port)\n");
            socket.send_to(new InetSocketAddress(address, (uint16)port), new uint8[] { DGRAM_INQUIRE });
        }

        public static uint16 find_free_port(string ip_address) {
            uint16 port = 2000;
            var address = new InetAddress.from_string(ip_address);
            while(true) {
                try {
                    var socket_addr = new InetSocketAddress(address, port);
                    var socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
                    socket.bind(socket_addr, false);
                    socket.close();
                    return port;
                }
                catch {
                    port++;
                }
            }
        }

    }

}