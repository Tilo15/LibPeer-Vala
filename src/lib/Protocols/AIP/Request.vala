using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    public class Request<T> {
        public bool completed { get; set; }

        public virtual signal void response(T data) {
            print("Yeehaw\n");
            completed = true;
        }
    }
}