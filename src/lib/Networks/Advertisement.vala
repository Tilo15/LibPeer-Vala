using LibPeer.Protocols.Mx2;

namespace LibPeer.Networks
{
    
    public class Advertisement {

        public InstanceReference instance_reference;
        public PeerInfo peer_info;

        public Advertisement(InstanceReference instance_reference, PeerInfo peer_info) {
            this.instance_reference = instance_reference;
            this.peer_info = peer_info;
        }

    }

}