import argparse
import joblib
import codecs
import numpy as np
import sys

__author__ = 'jgcdesouza'


def main():
    parser = argparse.ArgumentParser(
        description="Using the trained model, outputs a list of k-nearest source words. Output is one line per test item with tabs separating different possibilities of neighbors.")
    parser.add_argument("model", help="path to the model in binary format.")
    # parser.add_argument("test_data", help="path to the test data.")

    parser.add_argument("-r", "--radius", type=float,
                        help="returns all neighbors within the radius passed as parameter.")
    parser.add_argument("-k", "--k_neighbors", type=int, default=5,
                        help="returns the k-nearest neighbors to the test points.")
    parser.add_argument("--debug", action="store_true", default=False, help="outputs debug mode.")

    args = parser.parse_args()

    sys.stderr.write("Reading binary file with trained models...\n")
    dict = joblib.load(args.model)
    source_models = dict["models"]
    words = dict["words"]

    # input_file = codecs.open(args.test_data, "r", "utf-8")
    input_file = sys.stdin
    n_topics = int(input_file.readline())
    topics = None
    for line in input_file:
        sline = line.strip()
        if sline == "":
            sys.stdout.write("\n")
            # pass
            # if args.debug:
            #     sys.stdout.write("\n")

        cols = sline.split(" ")
        src_word = None
        if len(cols) == n_topics:
            topics = np.array(map(float, cols))
        else:
            src_word = sline

        if topics is None:
            sys.stderr.write("error: topic distribution not found for phrase [%s]" % src_word)
            sys.exit(1)

        src_model = source_models.get(src_word, None)

        if src_model is not None:
            if args.radius:
                neighs = src_model.radius_neighbors(topics, radius=args.radius, return_distance=args.distance)
            else:
                if src_model._fit_X.shape[0] > args.k_neighbors:
                    dist, neighs = src_model.kneighbors(topics, n_neighbors=args.k_neighbors, return_distance=True)
                else:
                    dist, neighs = src_model.kneighbors(topics, n_neighbors=src_model._fit_X.shape[0], return_distance=True)

            possible_words = words[src_word]
            # print len(possible_words)
            # print neighs.ravel().shape
            # print dist.ravel().shape
            src_word = src_word.strip().encode("utf-8")
            sys.stdout.write("%s |||" % src_word)
            for i, word_pos in enumerate(neighs.ravel()):

                possible_translation = possible_words[word_pos]
                possible_translation = possible_translation.encode("utf-8")
                sys.stdout.write(" %s || %2.4f " % (possible_translation, dist.ravel()[i]))

                if word_pos != neighs.ravel()[-1]:
                    sys.stdout.write("||")
                else:
                    sys.stdout.write("|||| ")

if __name__ == "__main__":
    main()