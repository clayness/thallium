package thallium.impl;

import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.dart.DartGraphTrimmer;
import thallium.impl.rubis.RubisGraphTrimmer;

import java.io.File;
import java.util.Arrays;

public class GraphTrimmerMain {
    public static void main(String[] args) {
        try {
            ImmutableTriple<Double, Double, Double> weights = null;
            if (args.length > 4) {
                double[] weightvals = Arrays.stream(args[4].split(",")).mapToDouble(Double::parseDouble).toArray();
                weights = new ImmutableTriple<>(weightvals[0], weightvals[1], weightvals[2]);
            }
            switch (args[0]) {
                case "dart":
                    new DartGraphTrimmer(new File(args[1]), new File(args[2]), new File(args[3]), weights).run();
                    break;
                case "rubis":
                    new RubisGraphTrimmer(new File(args[1]), new File(args[2]), new File(args[3]),
                            12, 3, 10, weights).run();
                    break;
                default:
                    System.err.println("ERROR: unknown example name: " + args[0]);
                    System.exit(1);
                    break;
            }
        } catch (Exception e) {
            System.out.println("Unexpected error: " + e.getMessage());
            e.printStackTrace();
            System.exit(2);
        }
    }
}
