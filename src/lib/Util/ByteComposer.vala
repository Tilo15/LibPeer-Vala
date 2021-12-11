namespace LibPeer.Util {

    public class ByteComposer {

        private List<Bytes> components = new List<Bytes>();

        public ByteComposer add_byte(uint8 byte) {
            components.append(new Bytes({byte}));
            return this;
        }

        public ByteComposer add_bytes(Bytes bytes) {
            components.append(bytes);
            return this;
        }

        public ByteComposer add_byte_array(uint8[] bytes) {
            components.append(new Bytes(bytes));
            return this;
        }

        public ByteComposer add_char_array(char[] chars) {
            components.append(new Bytes((uint8[]) chars));
            return this;
        }

        public ByteComposer add_string(string str, bool remove_null_termination = true) {
            var data = (uint8[])str;
            if(remove_null_termination) {
                data = data[0:-1];
            }
            add_byte_array(data);
            return this;
        }

        public uint8[] to_byte_array() {
            uint8[] data = {};
            foreach (Bytes bytes in components) {
                foreach (uint8 byte in bytes.get_data()) {
                    data += byte;
                }
            }
            return data;
        }

        public Bytes to_bytes() {
            return new Bytes(to_byte_array());
        }

        public string to_string(bool null_terminate = true) {
            add_byte(0);
            return (string)to_byte_array();
        }

        public string to_escaped_string() {
            var builder = new StringBuilder();
            foreach (var byte in to_byte_array()) {
                if(byte >= 32 && byte <= 126) {
                    builder.append_unichar((unichar)byte);
                }
                else {
                    builder.append(@"[$(byte)d]");
                }
            }
            return builder.str;
        }
    }

}