using LibPeer.Protocols;
using LibPeer.Networks;
using LibPeer.Util;
using Sodium.Asymmetric;

namespace LibPeer.Protocols.Gdp {

    public class WrappedQuery : QueryBase {

        public QueryBase query { get; set; }

        public RouterInfo? router_info { get; set; }

        internal WrappedQuery.from_stream(uint8[] sender, uint8[] raw, DataInputStream stream) throws IOError, Error {
            raw_data = raw;
            sender_id = sender;
            
            if(stream.read_byte() != 31) {
                throw new IOError.INVALID_DATA("Invalid magic number");
            }

            if(stream.read_byte() % 2 == 1) {
                router_info = new RouterInfo.from_stream (stream);
            }
            query = QueryBase.new_from_stream (stream);
        }

        public void sign(uint8[] signing_key) throws Error {
            var data = new ByteComposer()
                .add_with_stream(s => {
                    s.put_byte(31);
                    s.put_byte(router_info != null ? 1 : 0);
                    if(router_info != null) {
                        router_info.serialise(s);
                    }
                    query.serialise(s);
                })
                .to_byte_array();

            var signed = Signing.sign(data, signing_key);
            raw_data = signed;
        }

        public WrappedQuery(uint8[] sender_id, QueryBase query, RouterInfo? router_info = null) {
            this.sender_id = sender_id;
            this.query = query;
            this.router_info = router_info;
        }
    }

    public class RouterInfo {
        
        public Mx2.InstanceReference instance_reference { get; set; }

        public PeerInfo[] connection_methods { get; set; }

        public RouterInfo.from_stream(DataInputStream stream) throws IOError, Error {
            instance_reference = new Mx2.InstanceReference.from_stream (stream);
            var qcms = stream.read_byte();
            connection_methods = new PeerInfo[qcms];
            for(var i = 0; i < qcms; i++) {
                connection_methods[i] = PeerInfo.deserialise(stream);
            }
        }

        public void serialise(DataOutputStream stream) throws Error {

            instance_reference.serialise(stream);
            stream.put_byte((uint8)connection_methods.length);
            foreach(var method in connection_methods) {
                method.serialise(stream);
            }
        }

        public RouterInfo(Mx2.InstanceReference instance_reference, PeerInfo[] connection_methods) {
            this.instance_reference = instance_reference;
            this.connection_methods = connection_methods;
        }
    }

}