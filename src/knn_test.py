import argparse
import joblib
import codecs
import numpy as np

__author__ = 'jgcdesouza'


def main():
    parser = argparse.ArgumentParser(
        description="Using the trained model, outputs a list of k-nearest source words. Output is one line per test item with tabs separating different possibilities of neighbors.")
    parser.add_argument("model", help="path to the model in binary format.")
    parser.add_argument("test_data", help="path to the test data.")

    parser.add_argument("-r", "--radius", type=float,
                        help="returns all neighbors within the radius passed as parameter.")
    parser.add_argument("-k", "--k_neighbors", type=int, default=5,
                        help="returns the k-nearest neighbors to the test points.")
    parser.add_argument("--distance", action="store_true", default=False,
                        help="whether or not to return distances with the nearest neighbors.")

    args = parser.parse_args()

    print "Reading binary file with trained models..."
    dict = joblib.load(args.model)
    source_models = dict["models"]
    words = dict["words"]

    input_file = codecs.open(args.test_data, "r", "utf-8")
    for line in input_file:
        sline = line.strip()
        tok = sline.split(" ||| ")
        src_word = tok[0]
        topics = np.array(map(float, tok[1].split(" ")))

        src_model = source_models.get(src_word, None)

        if src_model is not None:
            if args.radius:
                neighs = src_model.radius_neighbors(topics, radius=args.radius, return_distance=args.distance)
            else:
                if src_model._fit_X.shape[0] > args.k_neighbors:
                    neighs = src_model.kneighbors(topics, n_neighbors=args.k_neighbors, return_distance=args.distance)
                else:
                    neighs = src_model.kneighbors(topics, n_neighbors=src_model._fit_X.shape[0], return_distance=args.distance)

            print "[%s]" % src_word, #[words[src_word][i] for i in neighs]
            print type(neighs)

            for pos in neighs.ravel():
                # print pos
                possible_words = words[src_word]
                print "\t[%s]" % possible_words[pos]
        else:
            print "[%s]\tNULL" % src_word


if __name__ == "__main__":
    main()