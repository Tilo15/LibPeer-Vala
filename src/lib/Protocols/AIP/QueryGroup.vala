using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    internal class QueryGroup {

        private HashSet<InstanceReference> instances = new HashSet<InstanceReference>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        private int target;

        public QueryGroup(int target = 15) {
            this.target = target;
        }

        public void add_peer(InstanceReference instance) {
            instances.add(instance);
        }

        public bool actively_connect {
            get {
                return instances.size < target;
            }
        }

        public Iterator<InstanceReference> iterator() {
            return instances.iterator();
        }

    }

}