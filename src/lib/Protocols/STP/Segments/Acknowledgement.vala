namespace LibPeer.Protocols.Stp.Segments {

    public class Acknowledgement : Segment {

        protected override uint8 identifier { get { return SEGMENT_ACKNOWLEDGEMENT; } }

        public uint64 sequence_number { get; private set; }

        public uint64 timing { get; private set; }

        protected override void serialise_data (OutputStream stream) {
            //  print(@"***Ack segment $(sequence_number)\n");
            DataOutputStream os = new DataOutputStream (stream);
            os.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            os.put_uint64 (sequence_number);
            os.put_uint64 (timing);
            os.flush ();
        }

        public Acknowledgement.from_stream(InputStream stream) {
            DataInputStream ins = new DataInputStream (stream);
            ins.byte_order = DataStreamByteOrder.BIG_ENDIAN;
            sequence_number = ins.read_uint64 ();
            timing = ins.read_uint64 ();
        }

        public Acknowledgement(Payload segment) {
            sequence_number = segment.sequence_number;
            timing = segment.timing;
        }

    }

}