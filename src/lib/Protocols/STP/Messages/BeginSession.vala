namespace LibPeer.Protocols.Stp.Messages {

    public class BeginSession : Message {

        protected override uint8 message_type { get { return MESSAGE_BEGIN_SESSION; } }

        public Bytes session_id { get; private set; }

        public uint64 reply_timing { get; private set; }

        public BeginSession(Bytes id, uint64 timing) {
            session_id = id;
            reply_timing = timing;
        }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = new DataOutputStream (stream);
            os.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            os.write (session_id.get_data ());
            os.put_uint64 (reply_timing);
            os.flush ();
        }

        public BeginSession.from_stream(InputStream stream) {
            DataInputStream ins = new DataInputStream (stream);
            ins.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            var b_session_id = new uint8[16];
            ins.read(b_session_id);
            session_id = new Bytes(b_session_id);
            reply_timing = ins.read_uint64 ();
        }

    }

}