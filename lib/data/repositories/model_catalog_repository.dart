import '../../models/model_catalog.dart';

abstract class ModelCatalogRepository {
  Future<List<CatalogModel>> models();
}

class StaticModelCatalogRepository implements ModelCatalogRepository {
  const StaticModelCatalogRepository();

  static const List<CatalogModel> _models = [
    CatalogModel(
      id: 'llama-3.2-1b',
      name: 'Llama 3.2 1B',
      parameterCountLabel: '1.2B',
      parameterCountInBillions: 1.2,
      quantization: 'Q4_K_M',
      contextLength: 131072,
      sizeBytes: 810000000,
      description:
          'Smallest Llama — the fastest option here, trading quality for speed.',
      downloadUrl:
          'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'qwen2.5-1.5b',
      name: 'Qwen2.5 1.5B',
      parameterCountLabel: '1.5B',
      parameterCountInBillions: 1.5,
      quantization: 'Q4_K_M',
      contextLength: 32768,
      sizeBytes: 1000000000,
      description:
          "Alibaba's compact all-rounder. Strong everyday chat quality for its size.",
      downloadUrl:
          'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'gemma-2-2b',
      name: 'Gemma 2 2B',
      parameterCountLabel: '2.6B',
      parameterCountInBillions: 2.6,
      quantization: 'Q4_K_M',
      contextLength: 8192,
      sizeBytes: 1750000000,
      description:
          "Google's small model with a strong reputation for reasoning at this size.",
      downloadUrl:
          'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'qwen2.5-3b',
      name: 'Qwen2.5 3B',
      parameterCountLabel: '3.1B',
      parameterCountInBillions: 3.1,
      quantization: 'Q4_K_M',
      contextLength: 32768,
      sizeBytes: 2000000000,
      description:
          'Step up from the 1.5B — noticeably better reasoning, moderate speed.',
      downloadUrl:
          'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'llama-3.2-3b',
      name: 'Llama 3.2 3B',
      parameterCountLabel: '3.2B',
      parameterCountInBillions: 3.2,
      quantization: 'Q4_K_M',
      contextLength: 131072,
      sizeBytes: 2000000000,
      description: "Meta's 3B tuned for chat and multilingual use.",
      downloadUrl:
          'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'phi-3.5-mini',
      name: 'Phi 3.5 Mini',
      parameterCountLabel: '3.8B',
      parameterCountInBillions: 3.8,
      quantization: 'Q4_K_M',
      contextLength: 131072,
      sizeBytes: 2400000000,
      description:
          "Microsoft's 3.8B — unusually strong at math and reasoning for its size.",
      downloadUrl:
          'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
    ),
    CatalogModel(
      id: 'llama-3.1-8b',
      name: 'Llama 3.1 8B',
      parameterCountLabel: '8.0B',
      parameterCountInBillions: 8.0,
      quantization: 'Q3_K_M',
      contextLength: 131072,
      sizeBytes: 3900000000,
      description:
          "Meta's 8B — the best quality in this catalog, and the heaviest by far.",
      downloadUrl:
          'https://huggingface.co/bartowski/Llama-3.1-8B-Instruct-GGUF/resolve/main/Llama-3.1-8B-Instruct-Q3_K_M.gguf',
    ),
  ];

  @override
  Future<List<CatalogModel>> models() async => _models;
}
