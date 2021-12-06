using LibPeer.Networks.IPv4;

namespace GiveFile {

    class Main : Object {

        public static int main(string[] args) {
            print("Give File (IPv4)\n");
            string address = args[1];
            uint16 port = (uint16)int.parse(args[2]);

            var worker = new FileGiver(new IPv4(address, port), args[3]);

            while(true) {}

            return 0;
        }
    }

}