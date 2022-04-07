
using LibPeer.Protocols.Gdp;
using LibPeer.Protocols.Mx2;
using LibPeer.Networks;

namespace LibPeer.Routing {

    public class GdpInstanceResolver : InstanceResolver, Object {

        private Util.ConcurrentHashMap<InstanceReference, Gee.HashSet<PeerInfo>> instance_lookup = new Util.ConcurrentHashMap<InstanceReference, Gee.HashSet<PeerInfo>>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        public PeerInfo[] suggest_peer_info(InstanceReference instance_reference) {
            if(instance_lookup.has_key(instance_reference)) {
                return instance_lookup.get(instance_reference).to_array();
            }
            return new PeerInfo[] {};
        }

        public void add_peer_info(InstanceReference instance_reference, PeerInfo[] peer_info) {
            if(!instance_lookup.has_key(instance_reference)) {
                instance_lookup.set(instance_reference, new Gee.HashSet<PeerInfo>((a) => a.hash(), (a, b) => a.equals(b)));
            }
            var info_set = instance_lookup.get(instance_reference);
            foreach(var info in peer_info) {
                info_set.add(info);
            }
        }

    }

}