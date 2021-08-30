using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class AipCapabilities {

        public bool address_info { get; set; }
        public bool find_peers { get; set; }
        public bool query_answer { get; set; }

        public void serialise(OutputStream stream) throws IOError {
            var dos = new DataOutputStream(stream);
            dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;

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
            dos.write(data);
        }

        public AipCapabilities.from_stream(InputStream stream) throws IOError {
            var dis = new DataInputStream(stream);
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            var capability_count = dis.read_byte();

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