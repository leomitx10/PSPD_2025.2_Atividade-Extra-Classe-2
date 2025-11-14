package br.unb.cic.pspd.wordcount;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * WordCountDriver - Classe principal (Driver) para o WordCount
 *
 * Esta classe configura e executa o job MapReduce.
 * Função: Configurar o job, definir classes Mapper/Reducer, e executar
 *
 * Uso: hadoop jar wordcount.jar br.unb.cic.pspd.wordcount.WordCountDriver <input> <output>
 *
 * @author Grupo PSPD 2025.2 - UnB/FCTE
 */
public class WordCountDriver extends Configured implements Tool {

    /**
     * Método principal de execução do job
     *
     * @param args Argumentos: [0] = diretório de entrada, [1] = diretório de saída
     * @return 0 se sucesso, 1 se falha
     * @throws Exception
     */
    @Override
    public int run(String[] args) throws Exception {

        // Validação dos argumentos
        if (args.length != 2) {
            System.err.println("Uso: WordCountDriver <input_path> <output_path>");
            System.err.println("Exemplo: hadoop jar wordcount.jar br.unb.cic.pspd.wordcount.WordCountDriver /user/root/input /user/root/output");
            return 1;
        }

        // Cria uma nova configuração do Hadoop
        Configuration conf = getConf();

        // Cria um novo job
        Job job = Job.getInstance(conf, "WordCount - Contador de Palavras");

        // Define a classe JAR do job
        job.setJarByClass(WordCountDriver.class);

        // Define a classe Mapper
        job.setMapperClass(WordCountMapper.class);

        // Define a classe Combiner (otimização: agrega localmente antes do shuffle)
        // O Combiner é essencialmente um mini-Reducer que roda no mesmo nó do Mapper
        job.setCombinerClass(WordCountReducer.class);

        // Define a classe Reducer
        job.setReducerClass(WordCountReducer.class);

        // Define o tipo da chave de saída
        job.setOutputKeyClass(Text.class);

        // Define o tipo do valor de saída
        job.setOutputValueClass(IntWritable.class);

        // Define o caminho de entrada (lê do HDFS)
        FileInputFormat.addInputPath(job, new Path(args[0]));

        // Define o caminho de saída (escreve no HDFS)
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        // Exibe informações do job
        System.out.println("========================================");
        System.out.println("WordCount MapReduce Job");
        System.out.println("========================================");
        System.out.println("Input Path:  " + args[0]);
        System.out.println("Output Path: " + args[1]);
        System.out.println("Mapper:      " + WordCountMapper.class.getName());
        System.out.println("Reducer:     " + WordCountReducer.class.getName());
        System.out.println("Combiner:    " + WordCountReducer.class.getName() + " (otimização)");
        System.out.println("========================================");
        System.out.println();

        // Submete o job e aguarda conclusão
        // Retorna 0 se sucesso, 1 se falha
        return job.waitForCompletion(true) ? 0 : 1;
    }

    /**
     * Método main - Ponto de entrada da aplicação
     *
     * @param args Argumentos da linha de comando
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        // Cria uma nova configuração
        Configuration conf = new Configuration();

        // Executa o job usando ToolRunner (suporta opções genéricas do Hadoop)
        int exitCode = ToolRunner.run(conf, new WordCountDriver(), args);

        // Encerra com o código de saída
        System.exit(exitCode);
    }
}
