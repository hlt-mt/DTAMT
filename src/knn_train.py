import argparse
import codecs
import sys
import numpy as np
import joblib
import os.path
from sklearn.neighbors import NearestNeighbors
from collections import Counter

"""
reads the training input file in the format

number_of_positions_in_topic_vector
src_word ||| number_of_translations
translation_1 ||| 0 1 3 ... number_of_positions_in_topic_vector
...
translation_number_of_translations ||| 0 1 3 ... number_of_positions_in_topic_vector
"""

__author__ = 'jgcdesouza'


def main():
    parser = argparse.ArgumentParser(
        description='Trains a KNN model. Models are fitted with n_neighbors equal to the number of unique translation for each source phrase.')
    parser.add_argument("training_data", help="path to input training data file.")
    parser.add_argument("-m", "--model", help="path to save the output KNN model.")
    # parser.add_argument("-n", "--n_neighbors", type=int, default=3, help="number of neighbors. Default is 3.")
    # parser.add_argument("-r", "--radius", type=float, default=1.0,
    #                     help="radius of the nearest neighbor mode. Default is 1.0.")

    args = parser.parse_args()

    sys.stderr.write("Reading input file %s...\n" % args.training_data)
    training = codecs.open(args.training_data, "r", "utf-8")

    # reads the number of topics
    d = int(training.readline())

    src_phr_models = {}
    src_phr_trans = {}
    line_no = 0
    for line in training:
        line_no += 1
        sline = line.strip()
        field = sline.split(" ||| ")
        ## if the input file does not contain two columns after breaking on |||, there is a problem in the input file.
        if len(field) != 2:
            sys.stderr.write("line %d: ill-formed line (different than two tokens)\n" % line_no)
            sys.exit(1)

        src_phr = field[0]
        value = field[1].strip().split(" ")

        ## if the second column does not contain at least one token, there is a problem in the input file.
        if len(value) < 1:
            sys.stderr.write("line %d: ill-formed line (values column doesn't contain topics or entries no.\n" % line_no)
            sys.exit(2)

        ## if there is only one token, it represents the number of translations under a given source word.
        if len(value) == 1:
            # gets the number of entries
            tgt_no = int(value[0])

            sys.stderr.write("Reading [%s] (%d entries)\n" % (src_phr, tgt_no))

            # iterates over the next tgt_no lines to get all the translations at once
            src_training = []
            tgt_phr_list = []
            for tgt_id in xrange(tgt_no):
                tgt_line = training.readline()
                line_no += 1
                cols = tgt_line.split(" ||| ")
                if len(cols) != 2:
                    sys.stderr.write("line %d: ill-formed line (different than two tokens)\n" % line_no)
                    sys.exit(1)

                tgt_phr = cols[0]
                tgt_vec = cols[1].split(" ")
                tgt_arr = np.array(map(float, tgt_vec))
                src_training.append(tgt_arr)
                tgt_phr_list.append(tgt_phr)

            sys.stderr.write("Fitting model for [%s]...\n" % src_phr)
            X = np.row_stack(src_training)
            if X.shape[0] != tgt_no:
                sys.stderr.write("error: number of translations read differs from number of translations declared for word [%s]\n" % (src_phr))
                sys.exit(3)

            unique_tgt_phr_no = Counter(tgt_phr_list)
            neigh_est = NearestNeighbors(n_neighbors=len(unique_tgt_phr_no), radius=args.radius, algorithm="auto",
                                         metric='minkowski', p=2).fit(X)

            src_phr_models[src_phr] = neigh_est
            src_phr_trans[src_phr] = tgt_phr_list


    if args.model:
        print "Saving %d models...\n" % len(src_phr_models.keys())
        model_dir = os.path.dirname(args.model)
        if not os.path.exists(model_dir):
            os.makedirs(model_dir)
        d = {"words": src_phr_trans, "models": src_phr_models}
        joblib.dump(d, args.model)


if __name__ == "__main__":
    main()
