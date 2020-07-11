package thallium.impl;

import java.util.stream.Stream;

public abstract class Reward {
    public abstract boolean isDominated(Stream<? extends Reward> others);
}
