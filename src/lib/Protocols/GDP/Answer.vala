using LibPeer.Networks;
using Sodium.Asymmetric;

namespace LibPeer.Protocols.Gdp {

    public class Answer {

        protected uint8[] raw_data { get; set; }

        public Mx2.InstanceReference instance_reference { get; set; }

        public PeerInfo[] connection_methods { get; set; }

        public QueryBase query { get; set; }

        public QuerySummary query_summary { get; set; }

        public Answer.from_stream(DataInputStream stream) throws Error {

            var challenge_pk = new uint8[Signing.PUBLIC_KEY_BYTES];
            stream.read(challenge_pk);

            var signature_size = stream.read_uint16();
            raw_data = new uint8[signature_size];
            stream.read(raw_data);

            var data = Signing.verify(raw_data, challenge_pk);
            if(data == null) {
                throw new IOError.INVALID_DATA("Invalid answer signature");
            }

            var ds = new Util.ByteComposer().add_byte_array(data).to_stream();
            
            instance_reference = new Mx2.InstanceReference.from_stream(ds);

            var connection_method_count = ds.read_byte();
            connection_methods = new PeerInfo[connection_method_count];
            for(var i = 0; i < connection_method_count; i++) {
                connection_methods[i] = PeerInfo.deserialise(ds);
            }

            query = QueryBase.new_from_stream(ds);
            query_summary = new QuerySummary(query);

            if(!query_summary.challenge.check_key(challenge_pk)) {
                throw new IOError.INVALID_DATA("The answer challenge public key does not match the challenge public key found in the original query");
            }
        }

        public void serialise(DataOutputStream stream) throws Error requires (raw_data.length > 0) {
            stream.write(query_summary.challenge.public_key);
            stream.put_uint16((uint16)raw_data.length);
            stream.write(raw_data);
        }

        protected void sign() throws Error requires (query_summary.challenge.solved) {

            var data = new Util.ByteComposer()
                .add_with_stream(s => {
                    instance_reference.serialise(s);
                    s.put_byte((uint8)connection_methods.length);
                    foreach(var method in connection_methods) {
                        method.serialise(s);
                    }
                    query.serialise(s);
                })
                .to_byte_array();

            raw_data = query_summary.challenge.sign(data);
        }

        public Answer(QueryBase query, Mx2.InstanceReference instance, PeerInfo[] methods) throws Error {
            this.query = query;
            instance_reference = instance;
            connection_methods = methods;
            query_summary = new QuerySummary(query);
            sign();
        }
    }

}