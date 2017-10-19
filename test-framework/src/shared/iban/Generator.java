package shared.iban;

import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;
import org.iban4j.Iban;

public class Generator {

    private final IValueFactory values;

    public Generator(final IValueFactory values) {
        this.values = values;
    }

    public IString buildRandom() {
        String iban = new Iban.Builder()
                .buildRandom()
                .toString();

        return values.string(iban);
    }

}
