
using LibPeer.Networks;

namespace LibPeer.Networks.Simulation {

    class NetSimPeerInfo : PeerInfo {

        private const int IDENTIFIER_SIZE = 16;

        internal uint8[] identifier = new uint8[IDENTIFIER_SIZE];

        internal NetSimPeerInfo(Bytes identifier) {
            this.identifier = identifier.get_data();
        }

        public override GLib.Bytes get_network_identifier () {
            return new Bytes({'N', 'e', 't', 'S', 'i', 'm'});
        }

        protected override void build(uint8 data_length, InputStream stream) throws Error {
            identifier = stream.read_bytes(16).get_data();
        }

        protected override Bytes get_data_segment() {
            return new Bytes(identifier);
        }

        public override bool equals (PeerInfo other) {
            if (other is NetSimPeerInfo) {
                var oth = (NetSimPeerInfo)other;
                for(int i = 0; i < IDENTIFIER_SIZE; i++) {
                    if (oth.identifier[i] != identifier[i]) {
                        return false;
                    }
                }
                return true;
            }
            return false;
        }

        public override uint hash() {
            // XXX I'm sure this is the opposite of efficient
            return (new Bytes(identifier)).hash();
        }

        public override string to_string() {
            return "";
        }
    }

}