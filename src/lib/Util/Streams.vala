namespace LibPeer.Util {

    public class StreamUtil {

        public static DataInputStream get_data_input_stream(InputStream stream) {
            if(stream is DataInputStream) {
                return (DataInputStream)stream;
            }
            var dis = new DataInputStream(stream);
            dis.set_byte_order(DataStreamByteOrder.BIG_ENDIAN);
            return dis;
        }

        public static DataOutputStream get_data_output_stream(OutputStream stream) {
            if(stream is DataOutputStream) {
                return (DataOutputStream)stream;
            }
            var dos = new DataOutputStream(stream);
            dos.set_byte_order(DataStreamByteOrder.BIG_ENDIAN);
            return dos;
        }

    }

}