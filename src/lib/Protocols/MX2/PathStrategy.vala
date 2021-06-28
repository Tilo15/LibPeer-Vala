using LibPeer.Networks;

namespace LibPeer.Protocols.Mx2 {

    internal class PathStrategy {

        public PathInfo path { get; private set; }

        public PeerInfo first_hop { get; private set; }

        public PathStrategy(PathInfo path, PeerInfo first_hop) {
            this.path = path;
            this.first_hop = first_hop;
        }

    }

}