using LibPeer.Util;

namespace LibPeer.Protocols.Stp.Segments {

    public class Control : Segment {

        protected override uint8 identifier { get { return SEGMENT_CONTROL; } }

        public ControlCommand command { get; private set; }

        protected override void serialise_data (OutputStream stream) {
            DataOutputStream os = StreamUtil.get_data_output_stream(stream);
            os.put_byte(command.to_byte());
            os.flush ();
        }

        public Control.from_stream(InputStream stream) {
            DataInputStream ins = StreamUtil.get_data_input_stream(stream);
            command = ControlCommand.from_byte(ins.read_byte());
        }

        public Control(ControlCommand command) {
            this.command = command;
        }

    }

    public enum ControlCommand {
        COMPLETE,
        ABORT,
        NOT_CONFIGURED;

        public static ControlCommand from_byte(uint8 byte) {
            switch(byte) {
                case 0x04:
                    return COMPLETE;
                case 0x18:
                    return ABORT;
                case 0x15:
                    return NOT_CONFIGURED;
                default:
                    assert_not_reached();
            }
        }

        public uint8 to_byte() {
            switch(this) {
                case COMPLETE:
                    return 0x04;
                case ABORT:
                    return 0x18;
                case NOT_CONFIGURED:
                    return 0x15;
                default:
                    assert_not_reached();
            }
        }
    }

}