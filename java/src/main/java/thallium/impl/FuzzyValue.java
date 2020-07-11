package thallium.impl;

import org.apache.commons.lang3.tuple.ImmutableTriple;

final class FuzzyValue {
    private final ImmutableTriple<Double, Double, Double> values;
    private final ImmutableTriple<Double, Double, Double> weights;

    FuzzyValue(double pessimistic, double likely, double optimistic, ImmutableTriple<Double, Double, Double> weights) {
        // @formatter:off
        this.values  = ImmutableTriple.of(pessimistic, likely, optimistic);
        this.weights = weights;
        // @formatter:on
    }

    double getPessimistic() {
        return values.left;
    }

    double getOptimistic() {
        return values.right;
    }

    double getMostLikely() {
        return values.middle;
    }

    double getMin() {
        // @formatter:off
        return Math.min((1.0 - weights.left)   * values.left,
               Math.min((1.0 - weights.middle) * values.middle,
                        (1.0 - weights.right)  * values.right));
        // @formatter:on
    }
}
