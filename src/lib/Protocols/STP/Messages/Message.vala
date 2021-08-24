
namespace LibPeer.Protocols.Stp.Messages {

    public const uint8 MESSAGE_REQUEST_SESSION = 0x05;
    public const uint8 MESSAGE_NEGOTIATE_SESSION = 0x01;
    public const uint8 MESSAGE_BEGIN_SESSION = 0x06;
    public const uint8 MESSAGE_SEGMENT = 0x02;

    public abstract class Message : Object {

        protected abstract uint8 message_type { get; }

        public void serialise(OutputStream stream) {
            MemoryOutputStream buffer = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            buffer.write({message_type});
            serialise_data(buffer);
            var primmy = buffer.steal_data();
            primmy.length = (int)buffer.get_data_size();
            stream.write(primmy);
        }

        protected abstract void serialise_data(OutputStream stream);

        public static Message deserialise(InputStream stream) {
            uint8[] message = new uint8[1];
            stream.read(message);
            switch (message[0]) {
                case MESSAGE_REQUEST_SESSION:
                    return new RequestSession.from_stream(stream);
                case MESSAGE_NEGOTIATE_SESSION:
                    return new NegotiateSession.from_stream(stream);
                case MESSAGE_BEGIN_SESSION:
                    return new BeginSession.from_stream(stream);
                case MESSAGE_SEGMENT:
                    return new SegmentMessage.from_stream(stream);
                default:
                    assert_not_reached();
            }
        }

    }

}