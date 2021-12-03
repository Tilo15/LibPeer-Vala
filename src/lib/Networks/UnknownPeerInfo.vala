
namespace LibPeer.Networks
{
    /**
     * Used when a network type is encountered
     * that is not handled by the implementation
     */
    public class UnknownPeerInfo : PeerInfo {

        private Bytes information;
        private Bytes network_identifier;

        public override GLib.Bytes get_network_identifier () {
            return new Bytes(network_identifier.get_data());
        }

        protected override void build(uint8 data_length, InputStream stream, Bytes network_type) throws Error {
            information = stream.read_bytes(data_length);
            network_identifier = network_type;
        }

        protected override Bytes get_data_segment() {
            return information;
        }

        public override bool equals (PeerInfo other) {
            if (other is UnknownPeerInfo) {
                return ((UnknownPeerInfo)other).information.compare(information) == 0;
            }
            return false;
        }

        public override uint hash() {
            return information.hash();
        }

        public override string to_string() {
            return "Unknown-Network-Type";
        }

    }

}