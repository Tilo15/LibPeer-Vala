using LibPeer.Networks.Simulation;
using LibPeer.Routing;
using LibPeer.Networks;

namespace Discoverer {

    class Main : Object {

        public static int main(string[] args) {
            print("Discoverer\n");

            var counter = 0;
            var workers = new List<DiscoverWorker>();
            var routers = new List<Router>();
            var conduits = new List<Conduit>();
            Conduit? last_conduit = null;
            for(var i = 1; i < args.length; i++) {
                int count = int.parse(args[1]);
                Conduit conduit = new Conduit();
                if(last_conduit != null) {
                    var router = new Router(new Network[] {
                        last_conduit.get_interface (10, 10, 0.0f),
                        conduit.get_interface (10, 10, 0.0f)
                    });
                    routers.append(router);
                    print("Starting router\n");
                    router.start();
                }
                last_conduit = conduit;
                for (int j = 0; j< count; j++){
                    workers.append(new DiscoverWorker(counter, conduit.get_interface (10, 10, 0.0f)));
                    counter++;
                }
                conduits.append(conduit);
            }



            while(true) {};

            return 0;
        }
    }

}