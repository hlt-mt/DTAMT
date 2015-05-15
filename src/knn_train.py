import argparse
import codecs
import sys
import numpy as np
import joblib
from sklearn.neighbors import NearestNeighbors
from collections import Counter


__author__ = 'jgcdesouza'


def main():
    parser = argparse.ArgumentParser(
        description='Trains a KNN model. Models are fitted with n_neighbors equal to the number of unique translation for each source phrase.')
    parser.add_argument("training_data", help="path to input training data file.")
    parser.add_argument("-m", "--model", help="path to save the output KNN model.")
    # parser.add_argument("-n", "--n_neighbors", type=int, default=3, help="number of neighbors. Default is 3.")
    parser.add_argument("-r", "--radius", type=float, default=1.0,
                        help="radius of the nearest neighbor mode. Default is 1.0.")

    args = parser.parse_args()

    print "Reading input file %s..." % args.training_data
    training = codecs.open(args.training_data, "r", "utf-8")

    # reads the number of topics
    d = int(training.readline())

    line_counter = 1
    src_trn_data = {}
    src_trn_words = {}

    line_no = 0
    src_word_trn = []
    tgt_words_list = []
    for line in training:
        line_no += 1
        sline = line.strip()
        field = sline.split(" ||| ")
        ## if the input file does not contain two columns after breaking on |||, there is a problem in the input file.
        if len(field) != 2:
            sys.stderr.write("line %d: ill-formed line (different than two tokens)" % line_no)
            sys.exit(1)

        surface_word = field[0]
        value = field[1].strip().split(" ")

        ## if the second column does not contain at least one token, there is a problem in the input file.
        if len(value) < 1:
            sys.stderr.write("line %d: ill-formed line (values column doesn't contain topics or entries no." % line_no)
            sys.exit(2)

        ## if there is only one token, it represents the number of translations under a given source word.
        if len(value) == 1:
            # gets the number of entries
            tgt_no = int(value[0])

            print "[%s] %d" % (surface_word, tgt_no)

            # assigns list of topic distributions to corresponding entry of source word
            src_trn_data[surface_word] = src_word_trn
            # assigns list of tgt words to corresponding entry of source word
            src_trn_words[surface_word] = tgt_words_list
            # resets lists
            src_word_trn = []
            tgt_words_list = []

        ## else, if there is more than one token, this is the distribution of topics
        elif len(value) > 1:
            topic_dist = np.array(map(float, value))
            src_word_trn.append(topic_dist)
            tgt_words_list.append(surface_word)

    src_models = {}
    ## populating data structures
    for surface, data in src_trn_data.items():
        words = src_trn_words[surface]
        if len(data) == 0:
            continue
        counts = Counter(words)

        print "Processing [%s], (unique words = %d)" % (surface, len(counts))
        X = np.row_stack(data)
        neigh_est = NearestNeighbors(n_neighbors=len(counts), radius=args.radius, algorithm="auto",
                                     metric='minkowski', p=2).fit(X)
        src_models[surface] = neigh_est

    if args.model:
        print "Saving %d models..." % len(src_models.keys())
        d = {"words": src_trn_words, "models": src_models}
        joblib.dump(d, args.model, compress=3)


if __name__ == "__main__":
    main()
