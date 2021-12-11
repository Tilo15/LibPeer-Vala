using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class AipCapabilities {

        public bool address_info { get; set; }
        public bool find_peers { get; set; }
        public bool query_answer { get; set; }

        public void serialise(OutputStream stream) throws IOError {
            var dos = StreamUtil.get_data_output_stream(stream);

            var composer = new ByteComposer();
            if(address_info) {
                composer.add_byte(ApplicationInformationProtocol.CAPABILITY_ADDRESS_INFO);
            }
            if(find_peers) {
                composer.add_byte(ApplicationInformationProtocol.CAPABILITY_FIND_PEERS);
            }
            if(query_answer) {
                composer.add_byte(ApplicationInformationProtocol.CAPABILITY_QUERY_ANSWER);
            }

            var data = composer.to_byte_array();

            dos.put_byte((uint8)data.length);
            dos.flush();
            dos.write(data);
            dos.flush();
        }

        public AipCapabilities.from_stream(InputStream stream) throws IOError {
            var dis = StreamUtil.get_data_input_stream(stream);

            var capability_count = dis.read_byte();
            //  print(@"Reading $(capability_count) capabilities\n");

            for (var i = 0; i < capability_count; i++) {
                var byte = dis.read_byte();
                switch (byte) {
                    case ApplicationInformationProtocol.CAPABILITY_ADDRESS_INFO:
                        address_info = true;
                        break;
                    case ApplicationInformationProtocol.CAPABILITY_FIND_PEERS:
                        find_peers = true;
                        break;
                    case ApplicationInformationProtocol.CAPABILITY_QUERY_ANSWER:
                        query_answer = true;
                        break;
                }
            }
        }

        public bool has_capability_for_request_code(uint8 code) {
            return (code == ApplicationInformationProtocol.REQUEST_ADDRESS && address_info)
                || (code == ApplicationInformationProtocol.REQUEST_PEERS && find_peers)
                || code == ApplicationInformationProtocol.REQUEST_CAPABILITIES;
        }

    }

}