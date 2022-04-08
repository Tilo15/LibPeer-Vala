using LibPeer.Util;
using Sodium.Asymmetric;

namespace LibPeer.Protocols.Gdp {

    public class Query : QueryBase {

        public int max_hops { get; set; }

        public bool allow_routing { get; set; }
        
        public uint8[] namespace_hash { get; set; }
        
        public uint8[] resource_hash { get; set; }

        public uint8[] private_blob { get; set; }
        
        public Challenge challenge { get; set; }

        public void sign(uint8[] signing_key) throws Error requires (namespace_hash.length == ChecksumType.SHA256.get_length() && resource_hash.length == ChecksumType.SHA512.get_length()) {
            var data = new ByteComposer()
                .add_with_stream(s => {
                    s.put_byte(5);
                    s.put_byte((uint8) max_hops);
                    s.put_byte(allow_routing ? 1 : 0);
                    s.write(namespace_hash);
                    s.write(resource_hash);
                    s.write(challenge.public_key);
                    s.put_uint16((uint16)challenge.challenge_blob.length);
                    s.write(challenge.challenge_blob);
                    s.put_uint16((uint16)private_blob.length);
                    if(private_blob.length > 0) {
                        s.write(private_blob);
                    }
                })
                .to_byte_array();

            raw_data = Signing.sign(data, signing_key);
        }


        internal Query.from_stream(uint8[] sender, uint8[] raw, DataInputStream stream) throws IOError {
            raw_data = raw;
            sender_id = sender;
            
            if(stream.read_byte() != 5) {
                throw new IOError.INVALID_DATA("Invalid magic number");
            }

            max_hops = stream.read_byte();
            allow_routing = stream.read_byte() == 1;

            namespace_hash = new uint8[ChecksumType.SHA256.get_length()];
            stream.read(namespace_hash);

            resource_hash = new uint8[ChecksumType.SHA512.get_length()];
            stream.read(resource_hash);

            var challenge_pk = new uint8[Signing.PUBLIC_KEY_BYTES];
            stream.read(challenge_pk);

            var challenge_blob_size = stream.read_uint16();
            var challenge_blob = new uint8[challenge_blob_size];
            stream.read(challenge_blob);
            
            challenge = new Challenge.from_values(challenge_pk, challenge_blob);

            var private_blob_size = stream.read_uint16();
            private_blob = new uint8[private_blob_size];
            if(private_blob.length > 0) {
                stream.read(private_blob);
            }
        }

        internal void add_private_blob(uint8[] data, uint8[] key, uint8[] nonce) {
            private_blob = new ByteComposer()
                .add_byte_array(nonce)
                .add_byte_array(Sodium.Symmetric.encrypt(data, key, nonce))
                .to_byte_array();
        }
    }

}