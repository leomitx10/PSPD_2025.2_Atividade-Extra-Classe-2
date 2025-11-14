package br.unb.cic.pspd.wordcount;

import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

/**
 * WordCountMapper - Classe Mapper para o WordCount
 *
 * Esta classe implementa a fase de Map do paradigma MapReduce.
 * Função: Processar cada linha do arquivo de entrada e emitir pares (palavra, 1)
 *
 * Entrada: (offset, linha de texto)
 * Saída: (palavra, 1) para cada palavra encontrada
 *
 * @author Grupo PSPD 2025.2 - UnB/FCTE
 */
public class WordCountMapper extends Mapper<LongWritable, Text, Text, IntWritable> {

    // Constante para o valor 1 (reutilizada para eficiência)
    private final static IntWritable one = new IntWritable(1);

    // Objeto Text reutilizável para a palavra
    private Text word = new Text();

    /**
     * Método map: Processa cada linha do arquivo de entrada
     *
     * @param key     Offset da linha no arquivo (não utilizado aqui)
     * @param value   Linha de texto a ser processada
     * @param context Contexto para emitir pares chave-valor
     * @throws IOException
     * @throws InterruptedException
     */
    @Override
    public void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {

        // Converte a linha para String
        String line = value.toString();

        // Tokeniza a linha em palavras (separadas por espaços, tabs, etc.)
        StringTokenizer tokenizer = new StringTokenizer(line);

        // Itera sobre cada palavra
        while (tokenizer.hasMoreTokens()) {
            // Obtém a próxima palavra e converte para minúsculas
            String currentWord = tokenizer.nextToken().toLowerCase();

            // Remove caracteres especiais e mantém apenas letras e números
            currentWord = currentWord.replaceAll("[^a-zA-Z0-9]", "");

            // Ignora palavras vazias após limpeza
            if (currentWord.length() > 0) {
                // Define a palavra no objeto Text
                word.set(currentWord);

                // Emite o par (palavra, 1)
                context.write(word, one);
            }
        }
    }
}
