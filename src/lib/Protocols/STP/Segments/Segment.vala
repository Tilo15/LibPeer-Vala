
namespace LibPeer.Protocols.Stp.Segments {

    public const uint8 SEGMENT_ACKNOWLEDGEMENT = 0x06;
    public const uint8 SEGMENT_CONTROL = 0x10;
    public const uint8 SEGMENT_PAYLOAD = 0x0E;

    public abstract class Segment : Object {

        protected abstract uint8 identifier { get; }

        public void serialise(OutputStream stream) {
            MemoryOutputStream buffer = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            buffer.write({identifier});
            serialise_data(buffer);
            var primmy = buffer.steal_data();
            primmy.length = (int)buffer.get_data_size();
            stream.write(primmy);
        }

        protected abstract void serialise_data(OutputStream stream);

        public static Segment deserialise(InputStream stream) {
            uint8[] segment_type = new uint8[1];
            stream.read(segment_type);
            switch (segment_type[0]) {
                case SEGMENT_ACKNOWLEDGEMENT:
                    return new Acknowledgement.from_stream(stream);
                case SEGMENT_CONTROL:
                    return new Control.from_stream(stream);
                case SEGMENT_PAYLOAD:
                    return new Payload.from_stream(stream);
                default:
                    assert_not_reached();
            }
        }

    }

}