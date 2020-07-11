package thallium.impl.dart;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.ConfigReader;
import thallium.impl.GraphTrimmer;
import thallium.impl.Reward;

import java.io.*;
import java.util.Scanner;
import java.util.function.Function;

public class DartGraphTrimmer extends GraphTrimmer<DartSystemConfig> implements Runnable {

    private final ImmutableTriple<Double, Double, Double> weights;
    private final File configsFile;
    private final File fuzzyDir;
    private final File outDir;

    private final int numLevels = 5;
    private final int numFormations = 2;
    private final int latency = 2;

    public DartGraphTrimmer(File configs, File fuzzyDir, File outDir, ImmutableTriple<Double, Double, Double> weights) {
        this.weights = weights == null ? ImmutableTriple.of(0.0, 0.5, 0.5) : weights;
        this.configsFile = configs;
        this.fuzzyDir = fuzzyDir;
        this.outDir = outDir;

        outDir.mkdirs();
    }

    @Override
    public void run() {
        try (PrintWriter writer = new PrintWriter(new FileWriter(new File(outDir, "trimmed.txt")))) {
            // read the YAML file
            ImmutablePair<DartSystemConfig[], ObjectNode> yaml =
                    ConfigReader.readConfigFile(configsFile, DartSystemConfig.class);
            Function<String, DartSystemConfig> cfgLookup = x -> yaml.left[Integer.parseInt(x)];
            // read the fuzzy values into a matrix
            DartReward[][][][][][][] fuzzies = readFuzzyValues(fuzzyDir);
            Function<DartSystemConfig, Reward> rwdLookup = x ->
                    fuzzies[x.altitude][x.formation][x.ecm ? 1 : 0][x.incAltProgress][x.decAltProgress][x.incAlt2Progress][x.decAlt2Progress];
            // iterate over the reachability graph (yaml.right) and print each transition
            printTransitions(writer, cfgLookup, rwdLookup, yaml.right.fields());

            System.out.println("ok");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @SuppressWarnings("Duplicates")
    private DartReward[][][][][][][] readFuzzyValues(File fuzzyDir) {
        DartReward[][][][][][][] retval =
                new DartReward[this.numLevels][this.numFormations][2][this.latency][this.latency][this.latency][this.latency];
        try (
                BufferedReader detectedRead = new BufferedReader(new FileReader(new File(fuzzyDir,
                        String.format("detected-fuzzy-%04.2f-%04.2f-%04.2f.txt", weights.left, weights.middle, weights.right))));
                BufferedReader distanceRead = new BufferedReader(new FileReader(new File(fuzzyDir,
                        String.format("distance-fuzzy-%04.2f-%04.2f-%04.2f.txt", weights.left, weights.middle, weights.right))))
        ) {
            while (true) {
                String detectedLine = detectedRead.readLine();
                String distanceLine = distanceRead.readLine();
                if (detectedLine == null || distanceLine == null)
                    break;

                Scanner detected = new Scanner(detectedLine);
                Scanner distance = new Scanner(distanceLine);

                // @formatter:off
                int alt = detected.nextInt(); distance.nextInt();
                int frm = detected.nextInt(); distance.nextInt();
                int ecm = detected.nextInt(); distance.nextInt();
                int i1p = detected.nextInt(); distance.nextInt();
                int d1p = detected.nextInt(); distance.nextInt();
                int i2p = detected.nextInt(); distance.nextInt();
                int d2p = detected.nextInt(); distance.nextInt();
                // @formatter:on
                retval[alt - 1][frm][ecm][(latency - 1) - i1p][(latency - 1) - d1p][i2p][d2p] =
                        new DartReward(detected.nextDouble(), distance.nextDouble());

            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return retval;

    }

    @Override
    protected String formatOneTransition(DartSystemConfig src, ImmutablePair<DartSystemConfig, Boolean> pair,
                                         Function<DartSystemConfig, Reward> rwdLookup) {
        DartSystemConfig dst = pair.left;
        DartReward rwd = (DartReward) rwdLookup.apply(dst);
        return String.format("%2d,%2d,%2d,%2d,%2d,%2d,%2d -> %2d,%2d,%2d,%2d,%2d,%2d,%2d (%f,%f) : %s",
                src.altitude, src.formation, src.ecm ? 1 : 0, src.incAltProgress, src.decAltProgress, src.incAlt2Progress, src.decAlt2Progress,
                dst.altitude, dst.formation, dst.ecm ? 1 : 0, dst.incAltProgress, dst.decAltProgress, dst.incAlt2Progress, dst.decAlt2Progress,
                rwd == null ? Double.NaN : rwd.detected, rwd == null ? Double.NaN : rwd.distance, pair.right ? "-" : "+");
    }
}
