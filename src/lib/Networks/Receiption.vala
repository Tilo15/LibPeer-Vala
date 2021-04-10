
namespace LibPeer.Networks {

    public class Receiption {

        public InputStream stream;
        public PeerInfo peer_info;
        public Network network;

        public Receiption(InputStream stream, PeerInfo info, Network network) {
            this.stream = stream;
            this.peer_info = info;
            this.network = network;
        }

    }

}