using LibPeer.Networks.Simulation;

namespace GiveFile {

    class Main : Object {

        public static int main(string[] args) {
            print("Give File\n");

            Conduit conduit = new Conduit();

            FileGiver[] givers = new FileGiver[args.length-1];
            for(int i = 1; i < args.length; i++) {
                givers[i-1] = new FileGiver(conduit.get_interface (0, 0, 0.0f), args[i]);
            }

            while(true) {};

            return 0;
        }
    }

}