using LibPeer.Networks;
using LibPeer.Util;

using Gee;

namespace LibPeer.Protocols.Mx2 {

    public class Muxer {

        protected const int FALLBACK_PING_VALUE = 120000;
        
        protected ConcurrentHashMap<Bytes, HashSet<Network>> networks = new ConcurrentHashMap<Bytes, HashSet<Network>>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected ConcurrentHashMap<InstanceReference, Instance> instances = new ConcurrentHashMap<InstanceReference, Instance>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected ConcurrentHashMap<InstanceReference, InstanceAccessInfo> remote_instance_mapping = new ConcurrentHashMap<InstanceReference, InstanceAccessInfo>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected ConcurrentHashMap<Bytes, Inquiry> inquiries = new ConcurrentHashMap<Bytes, Inquiry>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected ConcurrentHashMap<InstanceReference, int> pings = new ConcurrentHashMap<InstanceReference, int>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected Fragmenter fragmenter = new Fragmenter();
        protected Assembler assembler = new Assembler();

        public void register_network(Network network) {
            // Get the network identifier
            Bytes network_identifier = network.get_network_identifier();

            // Do we have a set for this network type yet?
            if (!networks.has_key(network_identifier)) {
                // No, add one
                networks.set(network_identifier, new HashSet<Network>());
            }

            // Get the network set
            HashSet<Network> network_set = networks.get(network_identifier);

            // Do we have this network already?
            if (network_set.contains(network)) {
                // Yes, nothing to do
                return;
            }

            // Add the network to the set
            network_set.add(network);

            // Handle incoming data
            network.incoming_receiption.connect((receiption) => handle_receiption(receiption));
        }

        public Instance create_instance(string application_namespace) {
            // Create the instance
            Instance instance = new Instance(application_namespace);

            // Save the instance to the map
            instances.set(instance.reference, instance);

            // Return the instance
            return instance;
        }

        public Inquiry inquire(Instance instance, InstanceReference destination, PeerInfo[] peers, PathInfo? path = null) throws IOError, Error {
            // Create an inquiry
            var inquiry = new Inquiry(destination);
            inquiries.set(inquiry.id, inquiry);

            // Loop over each peer to try
            foreach (PeerInfo peer in peers) {
                // Get peer network identifier
                Bytes network_identifier = peer.get_network_identifier();
                // Do we have the network associated with the peer info?
                if (!networks.has_key(network_identifier)) {
                    // We don't have this peer's network
                    continue;
                }

                // Loop over the networks that match the type
                foreach (Network network in networks.get(network_identifier)) {
                    // Create the inquire packet
                    uint8[] packet = new ByteComposer()
                        .add_bytes(inquiry.id)
                        .add_char_array(instance.application_namespace.to_utf8())
                        .to_byte_array();

                        
                        // Create a frame containing an inquire packet
                    var path_info = path == null ? new PathInfo.empty() : path;
                    var frame = new Frame(destination, instance.reference, path_info, PayloadType.INQUIRE, packet);

                    // Send using the network and peer info
                    fragmenter.send_frame(frame, instance, network, peer);
                }
            }

            return inquiry;
        }

        public PeerInfo? get_peer_info_for_instance(InstanceReference instance) {
            if (remote_instance_mapping.has_key(instance)) {
                return remote_instance_mapping.get(instance).peer_info;
            }
            return null;
        }

        public Network? get_target_network_for_instance(InstanceReference instance) {
            if(remote_instance_mapping.has_key(instance)) {
                return remote_instance_mapping.get(instance).network;
            }
            return null;
        }

        public void send(Instance instance, InstanceReference destination, uint8[] data) throws IOError, Error {
            send_packet(instance, destination, PayloadType.DATA, data);
        }

        public int suggested_timeout_for_instance(InstanceReference instance) {
            if(pings.has_key(instance)) {
                return pings.get(instance) * 2;
            }
            return FALLBACK_PING_VALUE;
        }

        protected void send_packet(Instance instance, InstanceReference destination, PayloadType payload_type, uint8[] payload) throws IOError, Error {
            // Do we know the destination instance?
            if(!remote_instance_mapping.has_key(destination)) {
                // No, throw an error
                throw new IOError.HOST_NOT_FOUND("No known way to reach the specified instance");
            }

            // Get access information
            InstanceAccessInfo access_info = remote_instance_mapping.get(destination);

            // Create a frame
            Frame frame = new Frame(destination, instance.reference, access_info.path_info, payload_type, payload);

            // Send the frame over the network
            fragmenter.send_frame(frame, instance, access_info.network, access_info.peer_info);
        }

        protected void dispel_peer(Receiption receiption, Frame frame) throws Error {
            printerr(@"Dispelling peer at $(receiption.peer_info)\n");
            // Create a frame
            Frame dispel_frame = new Frame(frame.origin, frame.destination, frame.via.return_path, PayloadType.DISPEL, new uint8[0], FrameCrypto.NONE);

            // Send the frame over the network
            fragmenter.send_frame(dispel_frame, null, receiption.network, receiption.peer_info);
        }

        protected virtual void handle_receiption(Receiption receiption) {
            // Pass to the assembler
            var stream = assembler.handle_data(receiption.stream);

            // Did the assembler return a stream?
            if(stream == null) {
                // No, message is not fully assembled
                return;
            }

            // Read the incoming frame
            Frame frame = new Frame.from_stream(stream, instances);

            // Make a decision based on how well the frame was read
            switch (frame.read_status) {
                case FrameReadStatus.DECRYPTION_ERROR:
                case FrameReadStatus.INVALID_SIGNATURE:
                case FrameReadStatus.MALFORMED_FRAME:
                    return;
                case FrameReadStatus.INSTANCE_NOT_FOUND:
                    dispel_peer(receiption, frame);
                    return;
            }

            handle_frame(frame, receiption);
        }

        protected void handle_frame(Frame frame, Receiption receiption) {
            // Get the instance
            Instance instance = instances.get(frame.destination);

            // Determine what to do with the payload
            switch (frame.payload_type) {
                case PayloadType.INQUIRE:
                    handle_inquire(receiption, frame, instance);
                    break;
                
                case PayloadType.GREET:
                    handle_greet(receiption, frame, instance);
                    break;

                case PayloadType.DATA:
                    handle_payload(receiption, frame, instance);
                    break;

                case PayloadType.DISPEL:
                    handle_dispel(receiption, frame, instance);
                    break;

                default:
                    throw new IOError.INVALID_DATA("Invalid payload type");
            }
            
        }

        protected void handle_inquire(Receiption receiption, Frame frame, Instance instance) throws Error {
            // Next 16 bytes of packet is the inquiriy ID
            uint8[] inquiry_id = frame.payload[0:16];

            // Rest of the packet indicates the desired application namespace
            string application_namespace = new ByteComposer()
                .add_byte_array(frame.payload[16:frame.payload.length])
                .to_string();

            // Does the application namespace match the instance's
            if (instance.application_namespace == application_namespace) {
                // Yes, save this instance's information locally for use later
                if(!remote_instance_mapping.has_key(frame.origin)) {
                    remote_instance_mapping.set(frame.origin, new InstanceAccessInfo() { 
                        network = receiption.network,
                        peer_info = receiption.peer_info,
                        path_info = frame.via.return_path
                    });
                }

                print(@"Saved instance mapping with address $(receiption.peer_info.to_string()) due to inquiry\n");

                // Send the greeting
                send_packet(instance, frame.origin, PayloadType.GREET, inquiry_id);
            }
            else {
                printerr(@"$(instance.application_namespace) != $(application_namespace)\n");
            }

        }

        protected void handle_greet(Receiption receiption, Frame frame, Instance instance) throws Error {
            // We have received a greeting!
            // Have we received one from this instance before?
            if (!remote_instance_mapping.has_key(frame.origin)) {
                // No, this is the first (and therefore least latent) method of reaching this instance
                remote_instance_mapping.set(frame.origin, new InstanceAccessInfo() { 
                    network = receiption.network,
                    peer_info = receiption.peer_info,
                    path_info = frame.via.return_path
                });

                print(@"Saved instance mapping with address $(receiption.peer_info.to_string()) due to greeting\n");

                // Get the inquiry id
                Bytes inquiry_id = new Bytes(frame.payload[0:16]);

                // Determine the ping
                int ping = FALLBACK_PING_VALUE;
                if (inquiries.has_key(inquiry_id)) {
                    ping = inquiries.get(inquiry_id).response_received();
                }

                // Save the ping
                pings.set(frame.origin, ping);
            }

            // Does the instance know that this is now a reachable peer?
            if (!instance.reachable_peers.contains(frame.origin)) {
                // No, notify it
                instance.reachable_peers.add(frame.origin);
                instance.incoming_greeting(frame.origin);
            }
        }

        protected void handle_dispel(Receiption receiption, Frame frame, Instance instance) throws Error {
            print("Dispelled instance due to request from remote machine\n");
            // Received a dispel frame
            remote_instance_mapping.unset(frame.origin);
        }

        protected void handle_payload(Receiption receiption, Frame frame, Instance instance) throws Error {
            // Update access info - where we receive data from is always where we should send it back
            remote_instance_mapping.set(frame.origin, new InstanceAccessInfo() { 
                network = receiption.network,
                peer_info = receiption.peer_info,
                path_info = frame.via.return_path
            });

            MemoryInputStream stream = new MemoryInputStream.from_data(frame.payload);
            instance.incoming_payload(new Packet(frame.origin, frame.destination, stream));
        }

    }

}