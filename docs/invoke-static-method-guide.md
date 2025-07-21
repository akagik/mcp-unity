# Invoke Static Method Tool ガイド

`invoke_static_method`ツールを使用すると、任意のstaticメソッドを引数付きで呼び出すことができます。

## 基本的な使い方

### 構文

```json
{
  "typeName": "完全修飾型名",
  "methodName": "メソッド名",
  "parameters": [
    {
      "type": "パラメータ型",
      "value": パラメータ値
    }
  ]
}
```

## 使用例

### 1. Unity Debug.Log の呼び出し

```json
{
  "typeName": "UnityEngine.Debug",
  "methodName": "Log",
  "parameters": [
    {
      "type": "string",
      "value": "Hello from MCP Unity!"
    }
  ]
}
```

### 2. GameObject の作成

```json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "CreatePrimitive",
  "parameters": [
    {
      "type": "PrimitiveType",
      "value": "Cube"
    }
  ]
}
```

### 3. PlayerPrefs の操作

```json
{
  "typeName": "UnityEngine.PlayerPrefs",
  "methodName": "SetString",
  "parameters": [
    {
      "type": "string",
      "value": "PlayerName"
    },
    {
      "type": "string",
      "value": "MCP User"
    }
  ]
}
```

### 4. EditorUtility ダイアログの表示

```json
{
  "typeName": "UnityEditor.EditorUtility",
  "methodName": "DisplayDialog",
  "parameters": [
    {
      "type": "string",
      "value": "MCP Unity"
    },
    {
      "type": "string",
      "value": "このダイアログはMCP経由で作成されました！"
    },
    {
      "type": "string",
      "value": "OK"
    }
  ]
}
```

### 5. Vector3 パラメータの使用

```json
{
  "typeName": "YourNamespace.YourClass",
  "methodName": "SetPosition",
  "parameters": [
    {
      "type": "Vector3",
      "value": {
        "x": 10.5,
        "y": 2.0,
        "z": -5.3
      }
    }
  ]
}
```

### 6. 配列パラメータの使用

```json
{
  "typeName": "YourNamespace.StringProcessor",
  "methodName": "ProcessStrings",
  "parameters": [
    {
      "type": "string[]",
      "value": ["first", "second", "third"]
    }
  ]
}
```

### 7. 複数の引数を持つメソッド

```json
{
  "typeName": "UnityEngine.Mathf",
  "methodName": "Clamp",
  "parameters": [
    {
      "type": "float",
      "value": 15.7
    },
    {
      "type": "float",
      "value": 0.0
    },
    {
      "type": "float",
      "value": 10.0
    }
  ]
}
```

## サポートされている型

### 基本型
- `string` - 文字列
- `int` / `int32` - 32ビット整数
- `float` / `single` - 単精度浮動小数点数
- `double` - 倍精度浮動小数点数
- `bool` / `boolean` - ブール値
- `long` / `int64` - 64ビット整数

### Unity型
- `Vector2` - 2次元ベクトル `{"x": 0, "y": 0}`
- `Vector3` - 3次元ベクトル `{"x": 0, "y": 0, "z": 0}`
- `Color` - 色 `{"r": 1, "g": 0, "b": 0, "a": 1}`
- `GameObject` - GameObjectの名前を文字列で指定

### 配列型
- `string[]` - 文字列配列
- `int[]` - 整数配列
- `float[]` - 浮動小数点数配列

### 列挙型
列挙型は文字列として値を指定します：
```json
{
  "type": "PrimitiveType",
  "value": "Cube"
}
```

## 高度な使用例

### カスタムクラスのstaticメソッド呼び出し

```csharp
// C# コード例
namespace MyGame.Utils
{
    public static class GameManager
    {
        public static void StartNewGame(string playerName, int difficulty, bool tutorialEnabled)
        {
            // ゲーム開始処理
        }
    }
}
```

MCP経由での呼び出し：
```json
{
  "typeName": "MyGame.Utils.GameManager",
  "methodName": "StartNewGame",
  "parameters": [
    {
      "type": "string",
      "value": "Player1"
    },
    {
      "type": "int",
      "value": 2
    },
    {
      "type": "bool",
      "value": true
    }
  ]
}
```

### 戻り値の取得

メソッドが値を返す場合、レスポンスに含まれます：

```csharp
// C# コード
public static class Calculator
{
    public static float Add(float a, float b)
    {
        return a + b;
    }
}
```

呼び出し：
```json
{
  "typeName": "Calculator",
  "methodName": "Add",
  "parameters": [
    {
      "type": "float",
      "value": 10.5
    },
    {
      "type": "float",
      "value": 20.3
    }
  ]
}
```

レスポンス例：
```
Successfully invoked Calculator.Add

Return value: 30.8
Return type: System.Single
```

## エラーハンドリング

### よくあるエラー

1. **型が見つからない**
   - 完全修飾型名を使用してください（namespace.className）
   - アセンブリがロードされていることを確認してください

2. **メソッドが見つからない**
   - メソッド名のスペルを確認してください
   - メソッドがstaticであることを確認してください
   - パラメータの数と型が一致していることを確認してください

3. **パラメータ変換エラー**
   - サポートされている型を使用してください
   - JSON形式が正しいことを確認してください

## セキュリティに関する注意

このツールは非常に強力で、任意のstaticメソッドを実行できます。以下の点に注意してください：

1. **信頼できるユーザーのみに使用を許可する**
2. **危険なメソッドの実行を避ける**（ファイル削除、システム設定変更など）
3. **本番環境では使用を制限することを検討する**

## トラブルシューティング

### メソッドが見つからない場合
1. 型名が正しいか確認（大文字小文字も含めて）
2. メソッドがpublicかつstaticであることを確認
3. パラメータの型と数が正確に一致しているか確認

### パラメータエラーの場合
1. JSON形式が正しいか確認
2. 型名が正しいか確認（`int`と`Int32`は同じ）
3. Unity型の場合、必要なフィールドがすべて含まれているか確認

このツールを使用することで、Unity内のほぼすべてのstatic APIにアクセスでき、柔軟な自動化が可能になります。