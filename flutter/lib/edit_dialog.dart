import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/l10n/l10n.dart';

class EditDialog extends StatefulWidget {
  final Source source;
  final AsyncCallback afterSave;
  final BuildContext parentContext;
  const EditDialog({
    super.key,
    required this.source,
    required this.afterSave,
    required this.parentContext,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  /// Names already used by another source, as in setup.dart.
  final Set<String> _takenNames = {};

  bool get _isXtream => widget.source.sourceType == SourceType.xtream;

  Future<void> _save() async {
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }
    final name = (_formKey.currentState?.value["name"] as String? ?? "").trim();
    // The source keeps its own name, so only a different one can clash.
    if (name != widget.source.name &&
        await NativeBridge.instance.sourceNameExists(name)) {
      if (!mounted) return;
      setState(() => _takenNames.add(name));
      _formKey.currentState?.validate();
      return;
    }
    if (!mounted || !widget.parentContext.mounted) return;
    Navigator.of(context).pop();
    await Error.tryAsyncNoLoading(
      () async => await NativeBridge.instance.updateSource(
        Source(
          id: widget.source.id,
          name: name,
          sourceType: widget.source.sourceType,
          url: _formKey.currentState?.value["url"],
          username: _isXtream ? _formKey.currentState?.value["username"] : null,
          password: _isXtream ? _formKey.currentState?.value["password"] : null,
        ),
      ),
      widget.parentContext,
    );
    await widget.afterSave();
  }

  String? _validateName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (_takenNames.contains(trimmed)) {
      return tr("Name already exists");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: AlertDialog(
          title: Text(tr("Edit source {name}", {"name": widget.source.name})),
          actions: [
            TextButton(onPressed: _save, child: Text(tr("Save"))),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr("Cancel")),
            ),
          ],
          content: FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                FormBuilderTextField(
                  autofocus: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  initialValue: widget.source.name,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: tr("This field cannot be empty."),
                    ),
                    _validateName,
                  ]),
                  decoration: InputDecoration(
                    labelText: tr("Name"),
                    prefixIcon: const Icon(Icons.label_outline),
                    border: const OutlineInputBorder(),
                  ),
                  name: 'name',
                ),
                const SizedBox(height: 30),
                FormBuilderTextField(
                  textInputAction: TextInputAction.next,
                  initialValue: widget.source.url,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: tr("This field cannot be empty."),
                    ),
                  ]),
                  decoration: InputDecoration(
                    labelText: tr("URL"),
                    prefixIcon: const Icon(Icons.link),
                    border: const OutlineInputBorder(),
                  ),
                  name: 'url',
                ),
                Visibility(
                  visible: _isXtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: _isXtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.username,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: tr("This field cannot be empty."),
                      ),
                    ]),
                    decoration: InputDecoration(
                      labelText: tr("Username"),
                      prefixIcon: const Icon(Icons.account_circle),
                      border: const OutlineInputBorder(),
                    ),
                    name: 'username',
                  ),
                ),
                Visibility(
                  visible: _isXtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: _isXtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.password,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: tr("This field cannot be empty."),
                      ),
                    ]),
                    decoration: InputDecoration(
                      labelText: tr("Password"),
                      prefixIcon: const Icon(Icons.password),
                      border: const OutlineInputBorder(),
                    ),
                    name: 'password',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
