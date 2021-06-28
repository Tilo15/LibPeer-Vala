
namespace LibPeer.Networks.Simulation {

    internal class Packet {
        public Bytes data;

        public NetSimPeerInfo peer_info;

        public Packet(NetSimPeerInfo origin, Bytes payload) {
            data = payload;
            peer_info = origin;
        }
    }

}