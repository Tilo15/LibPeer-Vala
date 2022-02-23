using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class AuthenticatedPeerKey {

        internal uint8[] public_key { get; public set; }
        private uint8[] secret_key { get; set; }
        
        internal uint8[] sign(uint8[] data) {
            return Sodium.Asymmetric.Signing.sign(data, secret_key);
        }

        public AuthenticatedPeerIdentity identity {
            owned get {
                var id = new AuthenticatedPeerIdentity();
                id.public_key = public_key;
                return id;
            }
        }

    }


}