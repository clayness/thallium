package thallium.impl.rubis;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.ConfigReader;
import thallium.impl.GraphTrimmer;
import thallium.impl.Reward;

import java.io.*;
import java.util.Scanner;
import java.util.function.Function;

public class RubisGraphTrimmer extends GraphTrimmer<RubisSystemConfig> implements Runnable {

    private final ImmutableTriple<Double, Double, Double> weights;

    private final File fuzzyDir;
    private final File srcYaml;
    private final File outdir;

    private final int progressCount;
    private final int dimmerCount;
    private final int serverCount;

    public RubisGraphTrimmer(File srcYaml, File fuzzyDir, File outdir, int serverCount, int progressCount, int dimmerCount, ImmutableTriple<Double, Double, Double> weights) {
        this.weights = weights == null ? ImmutableTriple.of(0.25, 0.5, 0.25) : weights;
        this.fuzzyDir = fuzzyDir;
        this.srcYaml = srcYaml;
        this.outdir = outdir;

        this.progressCount = progressCount;
        this.serverCount = serverCount;
        this.dimmerCount = dimmerCount;

        outdir.mkdirs();
    }

    @Override
    public void run() {
        try (PrintWriter writer = new PrintWriter(new File(outdir, "trimmed.txt"))) {
            // read the YAML file
            ImmutablePair<RubisSystemConfig[], ObjectNode> yaml =
                    ConfigReader.readConfigFile(srcYaml, RubisSystemConfig.class);
            Function<String, RubisSystemConfig> cfgLookup = x -> yaml.left[Integer.parseInt(x)];
            // read the fuzzy values into a 4D matrix
            RubisReward[][][] fuzzies = readFuzzyValues(fuzzyDir);
            Function<RubisSystemConfig, Reward> rwdLookup = x -> fuzzies[x.servers][(this.progressCount - x.progress) - 1][x.dimmer];
            // iterate over the reachability graph (yaml.right) and print each transition
            printTransitions(writer, cfgLookup, rwdLookup, yaml.right.fields());

            System.out.println("ok");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    protected String formatOneTransition(RubisSystemConfig src, ImmutablePair<RubisSystemConfig, Boolean> pair,
                                         Function<RubisSystemConfig, Reward> rwdLookup) {
        RubisSystemConfig dst = pair.left;
        RubisReward rwd = (RubisReward) rwdLookup.apply(dst);
        return String.format("%2d,%2d,%2d -> %2d,%2d,%2d (%f,%f,%f) : %s",
                src.servers + 1, (this.progressCount - 1) - src.progress, src.dimmer,
                dst.servers + 1, (this.progressCount - 1) - dst.progress, dst.dimmer,
                rwd.getCost(), rwd.getFido(), rwd.getTime(), pair.right ? "-" : "+");
    }


    private RubisReward[][][] readFuzzyValues(File fuzzyDir) {
        RubisReward[][][] retval = new RubisReward[this.serverCount][this.progressCount][this.dimmerCount];
        try (
                BufferedReader costRead = new BufferedReader(new FileReader(new File(fuzzyDir, String.format("cost-fuzzy-%04.2f-%04.2f-%04.2f.txt",
                        weights.left, weights.middle, weights.right))));
                BufferedReader fidoRead = new BufferedReader(new FileReader(new File(fuzzyDir, String.format("fido-fuzzy-%04.2f-%04.2f-%04.2f.txt",
                        weights.left, weights.middle, weights.right))));
                BufferedReader timeRead = new BufferedReader(new FileReader(new File(fuzzyDir, String.format("time-fuzzy-%04.2f-%04.2f-%04.2f.txt",
                        weights.left, weights.middle, weights.right))))
        ) {
            while (true) {
                String costLine = costRead.readLine();
                String fidoLine = fidoRead.readLine();
                String timeLine = timeRead.readLine();
                if (costLine == null || fidoLine == null || timeLine == null)
                    break;

                Scanner cost = new Scanner(costLine);
                Scanner fido = new Scanner(fidoLine);
                Scanner time = new Scanner(timeLine);

                // @formatter:off
                int s = cost.nextInt(); fido.nextInt(); time.nextInt();
                int p = cost.nextInt(); fido.nextInt(); time.nextInt();
                int d = cost.nextInt(); fido.nextInt(); time.nextInt();
                // @formatter:on
                retval[s - 1][p - 1][d - 1] =
                        new RubisReward(cost.nextDouble(), fido.nextDouble(), time.nextDouble());
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return retval;
    }
}
