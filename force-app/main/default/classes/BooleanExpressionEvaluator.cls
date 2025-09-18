public class BooleanExpressionEvaluator {
    public static Boolean evaluate(String expr) {
        expr = expr
            .replaceAll('(?i)true', '1')
            .replaceAll('(?i)false', '0')
            .replaceAll('\\s+', ' ')
            .trim();

        try {
            return parse(expr);
        } catch (Exception e) {
            System.debug('Failed to evaluate condition: ' + expr + ' => ' + e.getMessage());
            return false;
        }
    }

    private static Boolean parse(String expr) {
        if (expr == '1') return true;
        if (expr == '0') return false;

        // Handle parentheses recursively
        while (expr.contains('(')) {
            Integer start = expr.lastIndexOf('(');
            Integer endIdx = expr.indexOf(')', start);
            // if (endIdx == -1) throw new System.Exception('Unbalanced parentheses');

            String subExpr = expr.substring(start + 1, endIdx);
            Boolean result = parse(subExpr);
            expr = expr.substring(0, start) + (result ? '1' : '0') + expr.substring(endIdx + 1);
        }

        List<String> tokens = expr.split(' ');

        while (tokens.contains('NOT')) {
            Integer i = tokens.indexOf('NOT');
            Boolean val = tokens[i + 1] == '1' ? false : true;
            tokens.remove(i + 1);
            tokens.set(i, val ? '1' : '0');
        }

        while (tokens.contains('AND')) {
            Integer i = tokens.indexOf('AND');
            Boolean val = (tokens[i - 1] == '1') && (tokens[i + 1] == '1');
            tokens.set(i - 1, val ? '1' : '0');
            tokens.remove(i); tokens.remove(i);
        }

        while (tokens.contains('OR')) {
            Integer i = tokens.indexOf('OR');
            Boolean val = (tokens[i - 1] == '1') || (tokens[i + 1] == '1');
            tokens.set(i - 1, val ? '1' : '0');
            tokens.remove(i); tokens.remove(i);
        }

        return tokens.size() == 1 && tokens[0] == '1';
    }
}