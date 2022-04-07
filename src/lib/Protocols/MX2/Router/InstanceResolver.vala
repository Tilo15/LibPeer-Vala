using LibPeer.Networks;

namespace LibPeer.Protocols.Mx2 {

    public interface InstanceResolver : Object {

        public abstract PeerInfo[] suggest_peer_info(InstanceReference instance_reference);

    }

}