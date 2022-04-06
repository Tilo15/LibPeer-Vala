namespace LibPeer.Util {

    public class ByteComposer {

        
        private List<Bytes> components = new List<Bytes>();
        public delegate void StreamComposer(DataOutputStream stream) throws Error;

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

        public ByteComposer add_with_stream(StreamComposer composer) throws Error {

            var stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            var dos = new DataOutputStream(stream);
            composer(dos);
            dos.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();
            if(buffer.length > 0) {
                add_byte_array(buffer);
            }

            return this;
        }

        public ByteComposer add_from_stream(InputStream stream, uint64 count) throws Error {
            add_with_stream(s => {
                var buffer = new uint8[count];
                size_t read_size = 0;
                size_t last_read = 0;
                while(read_size != count && 0 != (last_read = stream.read(buffer))) {
                    read_size += last_read;
                    s.write(buffer[0:last_read]);
                }
            });

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

        public DataInputStream to_stream() {
            return new DataInputStream(new MemoryInputStream.from_data(to_byte_array()));
        }
    }

}