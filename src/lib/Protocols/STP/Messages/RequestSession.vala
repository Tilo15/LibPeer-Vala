namespace LibPeer.Protocols.Stp.Messages {

    public class RequestSession : Message {

        protected override uint8 message_type { get { return MESSAGE_REQUEST_SESSION; } }

        public Bytes session_id { get; private set; }

        public Bytes in_reply_to { get; private set; }

        public uint8[] feature_codes { get; private set; }

        public uint64 timing { get; private set; }

        public RequestSession(Bytes id, Bytes reply, uint8[] features) {
            session_id = id;
            in_reply_to = reply;
            feature_codes = features;
        }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = new DataOutputStream (stream);
            os.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            os.write (session_id.get_data());
            os.write (in_reply_to.get_data());
            os.put_byte ((uint8)feature_codes.length);
            os.write (feature_codes);
            os.put_uint64 (get_monotonic_time ()/1000);
            os.flush ();
        }

        public RequestSession.from_stream(InputStream stream) {
            DataInputStream ins = new DataInputStream (stream);
            ins.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            var b_session_id = new uint8[16];
            ins.read(b_session_id);
            session_id = new Bytes(b_session_id);
            var b_in_reply_to = new uint8[16];
            ins.read(b_in_reply_to);
            in_reply_to = new Bytes(b_in_reply_to);
            uint8 feature_count = ins.read_byte ();
            feature_codes = new uint8[feature_count];
            ins.read(feature_codes);
            timing = ins.read_uint64 ();
        }

    }

}