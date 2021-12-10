using Sodium;
using Gee;

using LibPeer.Util;

namespace LibPeer.Protocols.Mx2 {

    public class Frame {

        private const uint8[] MAGIC_NUMBER = {'M', 'X', '2'};

        public InstanceReference destination { get; private set; }
        
        public InstanceReference origin { get; private set; }

        public PathInfo via { get; private set; }

        public uint8[] payload { get; private set; }

        public Frame(InstanceReference destination, InstanceReference origin, PathInfo via, uint8[] payload) {
            this.destination = destination;
            this.origin = origin;
            this.via = via;
            this.payload = payload;
        }

        public void serialise(OutputStream stream, Instance instance)
            throws IOError
            requires (instance.reference.compare(origin) == 0)
        {
            // Magic number
            stream.write(MAGIC_NUMBER);

            // Write the destination key
            destination.serialise(stream);

            // Write the origin key
            origin.serialise(stream);

            // Write the via field
            via.serialise(stream);

            // Sign the data
            uint8[] signed_payload = Asymmetric.Signing.sign(payload, instance.sign_private_key);

            // Encrypt the signed payload
            uint8[] encrypted_signed_payload = Asymmetric.Sealing.seal(signed_payload, destination.public_key);

            // Write the signed and encrypted payload
            stream.write(encrypted_signed_payload);
        }

        public Frame.from_stream(InputStream stream, ConcurrentHashMap<InstanceReference, Instance> instances) throws IOError, Error{
            // Read the magic number
            uint8[] magic = new uint8[3];
            stream.read(magic);

            if(new Bytes(magic).compare(new Bytes(MAGIC_NUMBER)) != 0) {
                throw new IOError.FAILED("Invalid magic number");
            }

            // Read the destination
            destination = new InstanceReference.from_stream(stream);

            // Read the origin
            origin = new InstanceReference.from_stream(stream);

            // Do we have an instance matching the destination of this frame?
            if (!instances.has_key(destination)) {
                throw new IOError.FAILED("Message matches no provided instances");
            }

            // Get the instance
            Instance instance = instances.get(destination);

            // Read the via field
            via = new PathInfo.from_stream(stream);

            // The remainder of the stream is the encrypted payload
            uint8[] encrypted_signed_payload = new uint8[uint16.MAX];
            size_t bytes_read;
            stream.read_all(encrypted_signed_payload, out bytes_read);
            encrypted_signed_payload.resize((int)bytes_read);

            // Decrypt the payload
            uint8[]? signed_payload = Asymmetric.Sealing.unseal(encrypted_signed_payload, instance.seal_public_key, instance.seal_private_key);

            if (signed_payload == null) {
                throw new IOError.FAILED("Payload could not be decrypted");
            }

            // Verify the signature and get plaintext message
            uint8[]? payload = Asymmetric.Signing.verify(signed_payload, origin.verification_key);

            
            if (payload == null) {
                throw new IOError.FAILED("Payload signature is invalid");
            }
            

            this.payload = payload;
        }

    }

}