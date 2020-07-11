package thallium.impl;

import org.apache.commons.lang3.tuple.ImmutablePair;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Scanner;

public class BoundsReader<C extends SystemConfig> implements AutoCloseable {
    private final File src;
    private final SystemConfigFactory<C> factory;
    private BufferedReader reader;
    private int index = 0;

    BoundsReader(File src, SystemConfigFactory<C> factory) {
        this.src = src;
        this.factory = factory;
    }

    @Override
    public void close() throws Exception {
        if (reader != null)
            reader.close();
        reader = null;
    }

    BoundsSection nextSection() {
        try {
            // if the file reader isn't open, open it
            if (reader == null)
                reader = new BufferedReader(new FileReader(src));
            // skip two lines (assuming those are the headers)
            if (reader.readLine() == null)
                return null;
            reader.readLine();
            // return the generator for the rest
            return new BoundsSection(reader, index++);
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

    public interface SystemConfigFactory<C extends SystemConfig> {
        ImmutablePair<C, Double> createFromLine(int index, Scanner scanner);
    }

    class BoundsSection {

        private final BufferedReader reader;
        private final int index;

        BoundsSection(BufferedReader reader, int index) {
            this.reader = reader;
            this.index = index;
        }

        ImmutablePair<C, Double> nextConfig() {
            try {
                String line = reader.readLine();
                if (line == null || line.equals(""))
                    return null;
                return factory.createFromLine(index, new Scanner(line));
            } catch (IOException e) {
                e.printStackTrace();
                return null;
            }
        }
    }
}
