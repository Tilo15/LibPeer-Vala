using Sodium.Asymmetric;
using LibPeer.Networks;

namespace LibPeer.Protocols.Gdp {

    public abstract class QueryBase {

        protected uint8[] raw_data { get; set; }
        
        public uint8[] sender_id { get; set; }

        public static QueryBase new_from_stream(DataInputStream stream) throws IOError, Error {

            var sender_id = new uint8[Signing.PUBLIC_KEY_BYTES];
            stream.read(sender_id);

            var signature_len = stream.read_uint32();
            var signature = new Util.ByteComposer().add_from_stream(stream, signature_len).to_byte_array();

            var query = Signing.verify(signature, sender_id);

            if(query == null) {
                throw new IOError.INVALID_DATA("Invalid query signature");
            }

            var query_stream = new DataInputStream(new MemoryInputStream.from_data(query));
            if(query[0] == 5) {
                return new Query.from_stream(sender_id, signature, query_stream);
            }
            else if(query[0] == 31) {
                return new WrappedQuery.from_stream(sender_id, signature, query_stream);
            }

            throw new IOError.INVALID_DATA(@"Unrecognised query type $(query[0]).");
        }


        public virtual void serialise(DataOutputStream stream) throws IOError requires (raw_data.length > 0)  {
            stream.write(sender_id);
            stream.put_uint32((uint16)raw_data.length);
            stream.write(raw_data);
        }

        public bool compare_sender(uint8[] sender) {
            if(sender.length != sender_id.length) {
                return false;
            }
            for(var i = 0; i < sender.length; i++) {
                if(sender[i] != sender_id[i]){
                    return false;
                }
            }
            return true;
        }
    }
    
}