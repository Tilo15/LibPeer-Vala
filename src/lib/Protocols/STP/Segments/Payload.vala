using LibPeer.Util;

namespace LibPeer.Protocols.Stp.Segments {

    public class Payload : Segment {

        protected override uint8 identifier { get { return SEGMENT_PAYLOAD; } }

        public uint64 sequence_number { get; private set; }

        public uint64 timing { get; private set; default = 0; }

        public uint8[] data { get; private set; }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = StreamUtil.get_data_output_stream(stream);
            os.put_uint64 (sequence_number);
            update_timing();
            os.put_uint64 (timing);
            os.put_uint32 (data.length);
            os.write (data);
            os.flush ();
        }

        public Payload.from_stream(InputStream stream) {
            DataInputStream ins = StreamUtil.get_data_input_stream(stream);
            sequence_number = ins.read_uint64 ();
            timing = ins.read_uint64 ();
            uint32 data_length = ins.read_uint32 ();
            data = new uint8[data_length];
            ins.read(data);
        }

        public void update_timing() {
            timing = get_monotonic_time()/1000;
        }

        public void reset_timing() {
            timing = 0;
        }

        public Payload(uint64 sequence_number, uint8[] data) {
            this.sequence_number = sequence_number;
            this.data = data;
        }

    }

}