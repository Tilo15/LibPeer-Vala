
namespace LibPeer.Protocols.Mx2 {

    public class InstanceReference {

        public uint8[] verification_key { get; private set; }
        public uint8[] public_key { get; private set; }
        public const int SERIALISED_SIZE = 64;

        public InstanceReference(uint8[] verification_key, uint8[] public_key) 
        requires (verification_key.length == 32)
        requires (public_key.length == 32)
        {
            this.verification_key = verification_key;
            this.public_key = public_key;
        }

        public InstanceReference.from_stream(InputStream stream) throws IOError {
            verification_key = new uint8[32];
            stream.read(_verification_key);

            public_key = new uint8[32];
            stream.read(public_key);
        }

        public void serialise(OutputStream stream) throws IOError {
            stream.write(verification_key);
            stream.write(public_key);
        }

        public uint hash() {
            return to_bytes().hash();
        }

        public int compare(InstanceReference other) {
            return to_bytes().compare(other.to_bytes());
        }

        public Bytes to_bytes() {
            return new Util.ByteComposer()
            .add_byte_array(verification_key)
            .add_byte_array(public_key)
            .to_bytes();
        }

    }

}