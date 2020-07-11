package thallium.impl;

import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.dart.DartFuzzyValueCalculator;
import thallium.impl.rubis.RubisFuzzyValueCalculator;

import java.io.File;
import java.util.Arrays;

public class FuzzyValueCalculatorMain {
    public static void main(String[] args) {
        if (args.length < 3) {
            System.out.println("Usage: FuzzyValueCalculatorMain <rubis|dart> <input directory> <output directory> [weights]");
            System.exit(1);
        }
        ImmutableTriple<Double, Double, Double> weights = null;
        if (args.length > 3) {
            double[] weightvals = Arrays.stream(args[3].split(",")).mapToDouble(Double::parseDouble).toArray();
            weights = new ImmutableTriple<>(weightvals[0], weightvals[1], weightvals[2]);
        }
        switch (args[0]) {
            case "dart":
                (new DartFuzzyValueCalculator(new File(args[1]), new File(args[2]), weights)).run();
                break;
            case "rubis":
                (new RubisFuzzyValueCalculator(new File(args[1]), new File(args[2]), weights)).run();
                break;
            default:
                System.err.println("ERROR: unknown example name: " + args[0]);
                System.exit(1);
                break;
        }
    }
}
