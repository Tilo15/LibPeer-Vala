
namespace LibPeer.Protocols.Gdp {

    public class QuerySummary {

        public int max_hops { get; set; }

        public int actual_hops { get; set; }

        public bool allow_routing { get; set; }

        public Gee.LinkedList<RouterInfo> routing_path { get; set; }

        private Gee.HashSet<Bytes> sender_ids = new Gee.HashSet<Bytes>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        public Bytes namespace_hash { get; set; }
        
        public Bytes resource_hash { get; set; }

        public uint8[]? private_blob { get; set; }

        private uint8[] encrypted_private_blob { get; set; }
        
        public Challenge challenge { get; set; }

        public QuerySummary(QueryBase query) {

            var depth = 0;
            var q = query;

            routing_path = new Gee.LinkedList<RouterInfo>();

            while(q is WrappedQuery) {
                depth ++;
                var wrapped = (WrappedQuery)q;
                q = wrapped.query;
                if(wrapped.router_info != null) {
                    routing_path.add(wrapped.router_info);
                }
                sender_ids.add(new Bytes(wrapped.sender_id));
            }

            var main_query = (Query)q;
            sender_ids.add(new Bytes(main_query.sender_id));
            actual_hops = depth;
            max_hops = main_query.max_hops;
            allow_routing = main_query.allow_routing;
            namespace_hash = new Bytes(main_query.namespace_hash);
            resource_hash = new Bytes(main_query.resource_hash);
            challenge = main_query.challenge;
            encrypted_private_blob = main_query.private_blob;
        }

        public bool validate() {
            if(!allow_routing && routing_path.size > 0) {
                return false;
            }
            if(actual_hops > max_hops) {
                return false;
            }
            return true;
        }

        public bool should_forward(Bytes sender_id) {
            return actual_hops < max_hops && validate() && !has_visited(sender_id);
        }

        public bool is_null_resource() {
            for(var i = 0; i < resource_hash.length; i++) {
                if(resource_hash[0] != 0) {
                    return false;
                }
            }
            return true;
        }

        public bool has_visited(Bytes sender_id) {
            return sender_ids.contains(sender_id);
        }

        internal void read_private_blob(uint8[] key) {
            if(encrypted_private_blob.length == 0) {
                return;
            }
            var nonce = encrypted_private_blob[0:Sodium.Symmetric.NONCE_BYTES];
            var ciphertext = encrypted_private_blob[Sodium.Symmetric.NONCE_BYTES:encrypted_private_blob.length];
            private_blob = Sodium.Symmetric.decrypt(ciphertext, key, nonce);
        }
    }

}