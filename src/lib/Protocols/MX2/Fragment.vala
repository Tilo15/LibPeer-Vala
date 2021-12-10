
using LibPeer.Util;

namespace LibPeer.Protocols.Mx2 {

    public class Fragment {

        public const int HEADER_LENGTH = 16;

        public uint64 message_number { get; set; }

        public uint32 fragment_number { get; set; }

        public uint32 total_fragments { get; set; }

        public uint8[] payload { get; set;}

        public Fragment (uint64 message, uint32 number, uint32 total, uint8[] data) {
            message_number = message;
            fragment_number = number;
            total_fragments = total;
            payload = data;
        }

        public void serialise(OutputStream stream) throws Error, IOError {
            var dos = StreamUtil.get_data_output_stream(stream);
            dos.put_uint64(message_number);
            dos.put_uint32(fragment_number);
            dos.put_uint32(total_fragments);
            dos.put_uint16((uint16)payload.length);
            dos.write(payload);
            dos.flush();
        }

        public Fragment.from_stream(InputStream stream) throws Error, IOError {
            var dis = StreamUtil.get_data_input_stream(stream);
            message_number = dis.read_uint64();
            fragment_number = dis.read_uint32();
            total_fragments = dis.read_uint32();
            var payload_length = dis.read_uint16();
            payload = new uint8[payload_length];
            dis.read(payload);
            //  print(@"Fragment: mno = $(message_number); seqno = $(fragment_number); flen = $(total_fragments); size = $(payload_length);\n");
        }

    }

}