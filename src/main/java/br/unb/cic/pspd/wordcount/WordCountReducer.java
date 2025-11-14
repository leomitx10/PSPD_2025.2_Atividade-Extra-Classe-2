package br.unb.cic.pspd.wordcount;

import java.io.IOException;

import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

/**
 * WordCountReducer - Classe Reducer para o WordCount
 *
 * Esta classe implementa a fase de Reduce do paradigma MapReduce.
 * Função: Agregar todas as ocorrências de cada palavra e calcular a contagem total
 *
 * Entrada: (palavra, [1, 1, 1, ...])
 * Saída: (palavra, soma_total)
 *
 * @author Grupo PSPD 2025.2 - UnB/FCTE
 */
public class WordCountReducer extends Reducer<Text, IntWritable, Text, IntWritable> {

    // Objeto IntWritable reutilizável para o resultado
    private IntWritable result = new IntWritable();

    /**
     * Método reduce: Agrega os valores para cada chave (palavra)
     *
     * @param key     A palavra (chave)
     * @param values  Lista de contagens (todos são 1 neste caso)
     * @param context Contexto para emitir o resultado final
     * @throws IOException
     * @throws InterruptedException
     */
    @Override
    public void reduce(Text key, Iterable<IntWritable> values, Context context)
            throws IOException, InterruptedException {

        int sum = 0;

        // Soma todas as ocorrências da palavra
        for (IntWritable val : values) {
            sum += val.get();
        }

        // Define o resultado
        result.set(sum);

        // Emite o par (palavra, contagem_total)
        context.write(key, result);
    }
}
