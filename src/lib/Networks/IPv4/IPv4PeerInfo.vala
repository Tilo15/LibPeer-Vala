
using LibPeer.Networks;

namespace LibPeer.Networks.IPv4 {

    public class IPv4PeerInfo : PeerInfo {

        internal uint8[] address = new uint8[4];
        internal uint16 port = 0;

        internal IPv4PeerInfo(InetSocketAddress socket_address) {
            register_info_type();
            this.address = ip_string_to_bytes(socket_address.get_address().to_string());
            this.port = socket_address.get_port();
        }

        public override GLib.Bytes get_network_identifier () {
            return new Bytes({'I', 'P', 'v', '4'});
        }

        protected override void build(uint8 data_length, InputStream stream, Bytes network_type) throws Error
        requires (data_length == 6) {
            DataInputStream dis = new DataInputStream(stream);
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            
            for(int i = 0; i < 4; i ++) {
                address[i] = dis.read_byte();
            }

            port = dis.read_uint16();
        }

        protected override Bytes get_data_segment() {
            var stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            var dos = new DataOutputStream(stream);
            dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            for(int i = 0; i < 4; i ++) {
                dos.put_byte(address[i]);
            }

            dos.put_uint16(port);
            dos.flush();
            dos.close();

            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();
            return new Bytes(buffer);
        }

        public override bool equals (PeerInfo other) {
            if (other is IPv4PeerInfo) {
                var oth = (IPv4PeerInfo)other;
                for(int i = 0; i < 4; i++) {
                    if (oth.address[i] != address[i]) {
                        return false;
                    }
                }
                if(oth.port != port) {
                    return false;
                }
                return true;
            }
            return false;
        }

        public override uint hash() {
            // XXX I'm sure this is the opposite of efficient
            return get_data_segment().hash();
        }

        public override string to_string() {
            return @"IPv4://$(bytes_to_ip_string(address)):$(port)";
        }

        public InetSocketAddress to_socket_address() {
            InetAddress inet_address = new InetAddress.from_string(bytes_to_ip_string(address));
            return new InetSocketAddress(inet_address, port);
        }

        private static uint8[] ip_string_to_bytes(string ip) {
            var parts = ip.split(".", 4);
            var data = new uint8[4];
            for(int i = 0; i < 4; i++) {
                data[i] = (uint8)int.parse(parts[i]);
            }
            return data;
        }

        private static string bytes_to_ip_string(uint8[] data) {
            return @"$(data[0]).$(data[1]).$(data[2]).$(data[3])";
        }
    }

}