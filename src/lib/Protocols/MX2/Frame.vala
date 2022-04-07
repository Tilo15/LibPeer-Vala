using Sodium;
using Gee;

using LibPeer.Util;

namespace LibPeer.Protocols.Mx2 {

    public enum PayloadType {
        INQUIRE = 5,
        GREET = 6,
        DATA = 22,
        DISPEL = 21
    }

    public enum FrameCrypto {
        NONE = 0,
        SIGNED = 1,
        SIGNED_ENCRYPTED = 2
    }

    public enum FrameReadStatus {
        OK,
        MALFORMED_FRAME,
        INSTANCE_NOT_FOUND,
        INVALID_SIGNATURE,
        DECRYPTION_ERROR
    }

    public class Frame {

        private const uint8[] MAGIC_NUMBER = {'M', 'X', '2'};

        public InstanceReference destination { get; private set; }
        
        public InstanceReference origin { get; private set; }

        public PathInfo via { get; private set; }

        public FrameCrypto cryptography_level { get; private set; }

        public PayloadType payload_type { get; private set; }

        public uint8[] payload { get; private set; }

        public FrameReadStatus read_status { get; private set; }

        public Frame(InstanceReference destination, InstanceReference origin, PathInfo via, PayloadType type, uint8[] payload, FrameCrypto crypto_level = FrameCrypto.SIGNED_ENCRYPTED) {
            this.destination = destination;
            this.origin = origin;
            this.via = via;
            this.cryptography_level = crypto_level;
            this.payload_type = type;
            this.payload = payload;
        }

        public void serialise(OutputStream stream, Instance? instance)
            throws IOError
            requires (cryptography_level == FrameCrypto.NONE || instance != null)
        {
            // Magic number
            stream.write(MAGIC_NUMBER);

            // Write the destination key
            destination.serialise(stream);

            // Write the origin key
            origin.serialise(stream);

            // Write the via field
            via.serialise(stream);

            // Write the cryptography level
            stream.write(new uint8[] { (uint8) cryptography_level });

            // Create the data that is to be protected according to the crypto level
            uint8[] output = new ByteComposer()
                .add_byte((uint8) payload_type)
                .add_byte_array(payload)
                .to_byte_array();

            if(cryptography_level >= FrameCrypto.SIGNED) {
                // Sign the data
                output = Asymmetric.Signing.sign(output, instance.sign_private_key);

                if(cryptography_level >= FrameCrypto.SIGNED_ENCRYPTED) {
                    // Encrypt the signed payload
                    output = Asymmetric.Sealing.seal(output, destination.public_key);
                }
            }

            // Write the signed and encrypted payload
            stream.write(output);
        }

        public Frame.from_stream(InputStream stream, ConcurrentHashMap<InstanceReference, Instance> instances) throws IOError, Error{
            // Read the magic number
            uint8[] magic = new uint8[3];
            stream.read(magic);

            if(new Bytes(magic).compare(new Bytes(MAGIC_NUMBER)) != 0) {
                read_status = FrameReadStatus.MALFORMED_FRAME;
                return;
            }

            // Read the destination
            destination = new InstanceReference.from_stream(stream);

            // Read the origin
            origin = new InstanceReference.from_stream(stream);

            // Read the via field
            via = new PathInfo.from_stream(stream);

            // Read the crypto level field
            var level = new uint8[1];
            stream.read(level);
            cryptography_level = (FrameCrypto)level[0];

            // Do we have an instance matching the destination of this frame?
            if (!instances.has_key(destination)) {
                // No, unreadable 
                read_status = FrameReadStatus.INSTANCE_NOT_FOUND;
                return;
            }

            // The remainder of the stream is the payload
            uint8[]? frame_payload = new uint8[uint16.MAX];
            size_t bytes_read;
            stream.read_all(frame_payload, out bytes_read);
            frame_payload.resize((int)bytes_read);

            // If encryption was used, decrypt
            if(cryptography_level >= FrameCrypto.SIGNED_ENCRYPTED) {
                // Get the instance
                var instance = instances.get(destination);
                frame_payload = Asymmetric.Sealing.unseal(frame_payload, instance.seal_public_key, instance.seal_private_key);

                if(frame_payload == null) {
                    read_status = FrameReadStatus.DECRYPTION_ERROR;
                    return;
                }
            }

            // If signing was used, verify
            if(cryptography_level >= FrameCrypto.SIGNED) {
                frame_payload = Asymmetric.Signing.verify(frame_payload, origin.verification_key);

                if(frame_payload == null) {
                    read_status = FrameReadStatus.INVALID_SIGNATURE;
                    return;
                }
            }

            // Read the payload type
            payload_type = (PayloadType)frame_payload[0];
            if(!valid_combination(cryptography_level, payload_type)) {
                throw new IOError.INVALID_DATA("The payload type requires a higher cryptography level.");
            }

            // Save the payload
            payload = frame_payload[1:frame_payload.length];
            read_status = FrameReadStatus.OK;
        }

        public bool valid_combination(FrameCrypto crypto_level, PayloadType type) {
            switch (type) {
                case PayloadType.DATA:
                    return crypto_level >= FrameCrypto.SIGNED_ENCRYPTED;
                case PayloadType.INQUIRE:
                    return crypto_level >= FrameCrypto.SIGNED;
                case PayloadType.GREET:
                    return crypto_level >= FrameCrypto.SIGNED;
                case PayloadType.DISPEL:
                    return crypto_level >= FrameCrypto.NONE;
                default:
                    assert_not_reached();
            }
        }

    }

}