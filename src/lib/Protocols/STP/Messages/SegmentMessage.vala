using LibPeer.Protocols.Stp.Segments;

namespace LibPeer.Protocols.Stp.Messages {

    public class SegmentMessage : Message {

        protected override uint8 message_type { get { return MESSAGE_SEGMENT; } }

        public Bytes session_id { get; private set; }

        public Segment segment { get; private set; }

        public SegmentMessage(Bytes id, Segment segment) {
            session_id = id;
            this.segment = segment;
        }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = new DataOutputStream (stream);
            os.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            os.write (session_id.get_data ());
            segment.serialise (os);
            os.flush ();
        }

        public SegmentMessage.from_stream(InputStream stream) {
            DataInputStream ins = new DataInputStream (stream);
            ins.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            var b_session_id = new uint8[16];
            ins.read(b_session_id);
            session_id = new Bytes(b_session_id);
            segment = Segment.deserialise (ins);
        }

    }

}