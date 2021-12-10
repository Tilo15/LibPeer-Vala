using LibPeer.Util;

namespace LibPeer.Protocols.Stp.Segments {

    public class Acknowledgement : Segment {

        protected override uint8 identifier { get { return SEGMENT_ACKNOWLEDGEMENT; } }

        public uint64 sequence_number { get; private set; }

        public uint64 timing { get; private set; }

        protected override void serialise_data (OutputStream stream) {
            //  print(@"***Ack segment $(sequence_number)\n");
            DataOutputStream os = StreamUtil.get_data_output_stream(stream);
            os.put_uint64 (sequence_number);
            os.put_uint64 (timing);
            os.flush ();
        }

        public Acknowledgement.from_stream(InputStream stream) {
            DataInputStream ins = StreamUtil.get_data_input_stream(stream);
            sequence_number = ins.read_uint64 ();
            timing = ins.read_uint64 ();
        }

        public Acknowledgement(Payload segment) {
            sequence_number = segment.sequence_number;
            timing = segment.timing;
        }

    }

}