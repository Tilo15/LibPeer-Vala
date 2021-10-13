namespace LibPeer.Protocols.Stp.Messages {

    public class NegotiateSession : Message {

        protected override uint8 message_type { get { return MESSAGE_NEGOTIATE_SESSION; } }

        public Bytes session_id { get; private set; }

        public uint64 reply_timing { get; private set; }

        public uint8[] feature_codes { get; private set; }

        public uint64 timing { get; private set; }

        public NegotiateSession(Bytes id, uint8[] f_codes, uint64 timing) {
            session_id = id;
            feature_codes = f_codes;
            reply_timing = timing;
        }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = new DataOutputStream (stream);
            os.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            os.write (session_id.get_data ());
            os.put_byte ((uint8)feature_codes.length);
            if(feature_codes != null) {
                os.write (feature_codes);
            }
            os.put_uint64 (reply_timing);
            os.put_uint64 (get_monotonic_time ()/1000);
            os.flush ();
        }

        public NegotiateSession.from_stream(InputStream stream) {
            DataInputStream ins = new DataInputStream (stream);
            ins.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            var b_session_id = new uint8[16];
            ins.read(b_session_id);
            session_id = new Bytes(b_session_id);
            uint8 feature_count = ins.read_byte ();
            feature_codes = new uint8[feature_count];
            if(feature_codes != null) {
                ins.read(feature_codes);
            }
            reply_timing = ins.read_uint64 ();
            timing = ins.read_uint64 ();
        }

    }

}