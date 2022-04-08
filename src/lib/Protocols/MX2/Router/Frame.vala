
namespace LibPeer.Protocols.Mx2 {

    public class RouterFrame {
        private const uint8[] MAGIC_NUMBER = {'M', 'X', '2'};

        public InstanceReference destination { get; private set; }
        
        public InstanceReference origin { get; private set; }

        public PathInfo via { get; private set; }

        public uint8[] payload { get; private set; }

        public uint8[] to_buffer() throws Error {
            return new Util.ByteComposer()  
                .add_with_stream(s => serialise(s))
                .to_byte_array();
        }

        public Frame to_full_frame(Util.ConcurrentHashMap<InstanceReference, Instance> instances) throws Error {
            return new Frame.from_stream(new Util.ByteComposer().add_byte_array(to_buffer()).to_stream(), instances);
        }

        public void serialise(OutputStream stream) throws IOError {
            // Magic number
            stream.write(MAGIC_NUMBER);

            // Write the destination key
            destination.serialise(stream);

            // Write the origin key
            origin.serialise(stream);

            // Write the via field
            via.serialise(stream);

            // Write the payload
            stream.write(payload);
        }

        public RouterFrame.from_stream(InputStream stream) throws IOError, Error{
            // Read the magic number
            uint8[] magic = new uint8[3];
            stream.read(magic);

            if(new Bytes(magic).compare(new Bytes(MAGIC_NUMBER)) != 0) {
                throw new IOError.INVALID_DATA("Invalid magic number on frame.");
            }

            // Read the destination
            destination = new InstanceReference.from_stream(stream);

            // Read the origin
            origin = new InstanceReference.from_stream(stream);

            // Read the via field
            via = new PathInfo.from_stream(stream);

            // The remainder of the stream is the payload
            var data = new uint8[uint16.MAX];
            size_t bytes_read;
            stream.read_all(data, out bytes_read);
            data.resize((int)bytes_read);
            payload = data;
        }
    }

}