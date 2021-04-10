
namespace LibPeer.Protocols.Mx2 {

    public class InstanceReference {

        protected uint8[] verification_key;
        protected uint8[] public_key;

        public InstanceReference(uint8[] verification_key, uint8[] public_key) 
        requires (verification_key.length == 32)
        requires (public_key.length == 32)
        {
            this.verification_key = verification_key;
            this.public_key = public_key;
        }

        public InstanceReference.from_stream(InputStream stream) throws IOError {
            verification_key = new uint8[32];
            stream.read(verification_key);

            public_key = new uint8[32];
            stream.read(verification_key);
        }

        public void serialise(OutputStream stream) throws IOError {
            stream.write(verification_key);
            stream.write(public_key);
        }

    }

}